using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    private const string RuntimeSwitch = "--runtime";
    private const string SelfTestSwitch = "--self-test";
    private const string UpdaterMutexName = "CentralDeTrabalho_Atualizador";

    [STAThread]
    private static int Main(string[] args)
    {
        if (HasArgument(args, SelfTestSwitch))
        {
            return RunSelfTest(args);
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            if (HasArgument(args, RuntimeSwitch))
            {
                return RunUpdaterRuntime(args);
            }

            return StartUpdaterRuntime(args);
        }
        catch (Exception ex)
        {
            ShowFatal(ex.Message);
            return 1;
        }
    }

    private static int RunSelfTest(string[] args)
    {
        try
        {
            string updaterRoot = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string installRoot = GetArgumentValue(args, "-InstallRoot");
            if (string.IsNullOrWhiteSpace(installRoot))
            {
                DirectoryInfo parent = Directory.GetParent(updaterRoot);
                if (parent == null) return 20;
                installRoot = parent.FullName;
            }
            installRoot = Path.GetFullPath(installRoot);

            string[] updaterFiles =
            {
                "Central de Trabalho Updater.exe",
                "Central de Trabalho Updater.ps1",
                "Update.Core.ps1",
                "CANAIS.json"
            };
            foreach (string fileName in updaterFiles)
            {
                string path = Path.Combine(updaterRoot, fileName);
                if (!File.Exists(path) || new FileInfo(path).Length <= 0)
                {
                    return 21;
                }
            }

            string[] installFiles =
            {
                "Central de Trabalho.exe",
                "Central de Trabalho.ps1",
                @"Modulos\Central-de-Manutencao-CB5\Central Manutencao CB5.ps1",
                @"Modulos\Central-de-Manutencao-CB5\Manutencao.Core.ps1",
                @"Modulos\Gerador-de-Planilhas-CB5-TV5\Gerador Planilhas.ps1",
                @"Modulos\Gerador-de-Planilhas-CB5-TV5\Componentes.Core.ps1"
            };
            foreach (string relativePath in installFiles)
            {
                string path = Path.Combine(installRoot, relativePath);
                if (!File.Exists(path) || new FileInfo(path).Length <= 0)
                {
                    return 22;
                }
            }

            foreach (string script in new[]
            {
                Path.Combine(updaterRoot, "Central de Trabalho Updater.ps1"),
                Path.Combine(updaterRoot, "Update.Core.ps1")
            })
            {
                System.Management.Automation.Language.Token[] tokens;
                System.Management.Automation.Language.ParseError[] errors;
                System.Management.Automation.Language.Parser.ParseFile(script, out tokens, out errors);
                if (errors != null && errors.Length > 0)
                {
                    return 23;
                }
            }

            InitialSessionState state = InitialSessionState.CreateDefault();
            state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
            using (Runspace runspace = RunspaceFactory.CreateRunspace(state))
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (PowerShell ps = PowerShell.Create())
                {
                    ps.Runspace = runspace;
                    ps.AddScript("$PSVersionTable.PSVersion.Major -ge 5");
                    var result = ps.Invoke();
                    if (ps.HadErrors || result == null || result.Count != 1 || !LanguagePrimitives.IsTrue(result[0].BaseObject))
                    {
                        return 24;
                    }
                }
            }

            return 0;
        }
        catch
        {
            return 25;
        }
    }

    private static int StartUpdaterRuntime(string[] args)
    {
        if (IsUpdaterRuntimeRunning())
        {
            MessageBox.Show(
                "A tela de atualizações já está aberta.",
                "Central de Trabalho - Atualizador",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return 0;
        }

        string sourceDirectory = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string executablePath = Application.ExecutablePath;
        string installRoot = GetArgumentValue(args, "-InstallRoot");
        if (string.IsNullOrWhiteSpace(installRoot))
        {
            DirectoryInfo parent = Directory.GetParent(sourceDirectory);
            if (parent == null)
            {
                throw new InvalidOperationException("Não foi possível determinar a pasta de instalação da Central.");
            }
            installRoot = parent.FullName;
        }

        string runtimeRoot = Path.Combine(Path.GetTempPath(), "CentralDeTrabalho", "UpdaterRuntime");
        PrepareRuntimeDirectory(runtimeRoot);

        string[] runtimeFiles =
        {
            "Central de Trabalho Updater.exe",
            "Central de Trabalho Updater.ps1",
            "Update.Core.ps1",
            "CANAIS.json"
        };

        foreach (string fileName in runtimeFiles)
        {
            string source = string.Equals(fileName, "Central de Trabalho Updater.exe", StringComparison.OrdinalIgnoreCase)
                ? executablePath
                : Path.Combine(sourceDirectory, fileName);
            if (!File.Exists(source))
            {
                throw new FileNotFoundException("Arquivo necessário do Atualizador não foi encontrado.", source);
            }
            File.Copy(source, Path.Combine(runtimeRoot, fileName), true);
        }

        List<string> forwarded = new List<string>();
        forwarded.Add(RuntimeSwitch);
        bool hasInstallRoot = HasArgument(args, "-InstallRoot");
        for (int i = 0; i < args.Length; i++)
        {
            if (string.Equals(args[i], RuntimeSwitch, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            forwarded.Add(args[i]);
        }
        if (!hasInstallRoot)
        {
            forwarded.Add("-InstallRoot");
            forwarded.Add(installRoot);
        }

        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = Path.Combine(runtimeRoot, "Central de Trabalho Updater.exe");
        startInfo.WorkingDirectory = runtimeRoot;
        startInfo.Arguments = JoinArguments(forwarded);
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;

        Process process = Process.Start(startInfo);
        if (process == null)
        {
            throw new InvalidOperationException("Não foi possível iniciar o Atualizador em modo seguro.");
        }
        process.Dispose();
        return 0;
    }

    private static int RunUpdaterRuntime(string[] args)
    {
        bool createdNew;
        using (Mutex mutex = new Mutex(true, UpdaterMutexName, out createdNew))
        {
            if (!createdNew)
            {
                return 0;
            }

            string runtimeRoot = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string scriptPath = Path.Combine(runtimeRoot, "Central de Trabalho Updater.ps1");
            if (!File.Exists(scriptPath))
            {
                ShowFatal("O script do Atualizador não foi encontrado.\r\n\r\n" + scriptPath);
                return 2;
            }

            string installRoot = GetArgumentValue(args, "-InstallRoot");
            string currentVersion = GetArgumentValue(args, "-CurrentVersion") ?? string.Empty;
            int parentProcessId = 0;
            string parentText = GetArgumentValue(args, "-ParentProcessId");
            if (!string.IsNullOrWhiteSpace(parentText) && !int.TryParse(parentText, out parentProcessId))
            {
                ShowFatal("O identificador do processo principal recebido pelo Atualizador é inválido.");
                return 2;
            }
            if (string.IsNullOrWhiteSpace(installRoot))
            {
                ShowFatal("A pasta de instalação da Central não foi informada ao Atualizador.");
                return 2;
            }

            try
            {
                Directory.SetCurrentDirectory(runtimeRoot);

                InitialSessionState state = InitialSessionState.CreateDefault();
                state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;

                using (Runspace runspace = RunspaceFactory.CreateRunspace(state))
                {
                    runspace.ApartmentState = ApartmentState.STA;
                    runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                    runspace.Open();
                    runspace.SessionStateProxy.SetVariable("CentralUpdaterScriptPath", scriptPath);
                    runspace.SessionStateProxy.SetVariable("CentralInstallRoot", Path.GetFullPath(installRoot));
                    runspace.SessionStateProxy.SetVariable("CentralCurrentVersion", currentVersion);
                    runspace.SessionStateProxy.SetVariable("CentralParentProcessId", parentProcessId);

                    using (PowerShell ps = PowerShell.Create())
                    {
                        ps.Runspace = runspace;
                        ps.AddScript(". $CentralUpdaterScriptPath -InstallRoot $CentralInstallRoot -CurrentVersion $CentralCurrentVersion -ParentProcessId $CentralParentProcessId");
                        ps.Invoke();

                        if (ps.InvocationStateInfo != null && ps.InvocationStateInfo.State == PSInvocationState.Failed)
                        {
                            string message = ps.InvocationStateInfo.Reason != null
                                ? ps.InvocationStateInfo.Reason.Message
                                : "A execução interna do Atualizador foi encerrada com falha.";
                            ShowFatal(message);
                            return 3;
                        }
                        if (ps.HadErrors && ps.Streams.Error.Count > 0)
                        {
                            ShowFatal(ps.Streams.Error[0].ToString());
                            return 3;
                        }
                    }
                }

                return 0;
            }
            catch (Exception ex)
            {
                ShowFatal(ex.Message);
                return 1;
            }
            finally
            {
                try { mutex.ReleaseMutex(); }
                catch { }
            }
        }
    }

    private static void PrepareRuntimeDirectory(string runtimeRoot)
    {
        if (Directory.Exists(runtimeRoot))
        {
            try { Directory.Delete(runtimeRoot, true); }
            catch
            {
                string alternate = runtimeRoot + "-" + Guid.NewGuid().ToString("N");
                Directory.CreateDirectory(alternate);
                throw new IOException("Não foi possível preparar a pasta temporária do Atualizador. Feche qualquer Atualizador antigo e tente novamente.");
            }
        }
        Directory.CreateDirectory(runtimeRoot);
    }

    private static bool IsUpdaterRuntimeRunning()
    {
        try
        {
            using (Mutex existing = Mutex.OpenExisting(UpdaterMutexName))
            {
                return true;
            }
        }
        catch (WaitHandleCannotBeOpenedException)
        {
            return false;
        }
        catch
        {
            return false;
        }
    }

    private static bool HasArgument(string[] args, string name)
    {
        if (args == null) return false;
        for (int i = 0; i < args.Length; i++)
        {
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }
        return false;
    }

    private static string GetArgumentValue(string[] args, string name)
    {
        if (args == null) return null;
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
            {
                return args[i + 1];
            }
        }
        return null;
    }

    private static string JoinArguments(IEnumerable<string> args)
    {
        StringBuilder builder = new StringBuilder();
        foreach (string arg in args)
        {
            if (builder.Length > 0) builder.Append(' ');
            builder.Append(QuoteArgument(arg ?? string.Empty));
        }
        return builder.ToString();
    }

    private static string QuoteArgument(string value)
    {
        if (value.Length > 0 && value.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0)
        {
            return value;
        }

        StringBuilder builder = new StringBuilder();
        builder.Append('"');
        int backslashes = 0;
        for (int i = 0; i < value.Length; i++)
        {
            char c = value[i];
            if (c == '\\')
            {
                backslashes++;
                continue;
            }
            if (c == '"')
            {
                builder.Append('\\', backslashes * 2 + 1);
                builder.Append('"');
                backslashes = 0;
                continue;
            }
            if (backslashes > 0)
            {
                builder.Append('\\', backslashes);
                backslashes = 0;
            }
            builder.Append(c);
        }
        if (backslashes > 0)
        {
            builder.Append('\\', backslashes * 2);
        }
        builder.Append('"');
        return builder.ToString();
    }

    private static void ShowFatal(string details)
    {
        string message = "Não foi possível iniciar o Atualizador da Central de Trabalho.";
        if (!string.IsNullOrWhiteSpace(details))
        {
            message += "\r\n\r\n" + details;
        }

        MessageBox.Show(
            message,
            "Central de Trabalho - Atualizador",
            MessageBoxButtons.OK,
            MessageBoxIcon.Error);
    }
}

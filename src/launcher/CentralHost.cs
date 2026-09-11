using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    private const string SelfTestSwitch = "--self-test";
    private const string AppUserModelId = "CentralDeTrabalho.Desktop";

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string appID);

    [STAThread]
    private static int Main(string[] args)
    {
        string appRoot = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string scriptPath = Path.Combine(appRoot, "Central de Trabalho.ps1");

        if (HasArgument(args, SelfTestSwitch))
        {
            return RunSelfTest(appRoot);
        }

        ApplyShellIdentity();
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        if (!File.Exists(scriptPath))
        {
            ShowFatal("O arquivo principal da Central de Trabalho não foi encontrado.\r\n\r\n" + scriptPath);
            return 2;
        }

        try
        {
            Directory.SetCurrentDirectory(appRoot);

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
                    string escapedScriptPath = scriptPath.Replace("'", "''");

                    // O script principal precisa viver no escopo persistente do runspace.
                    // Isso mantém funções e comandos disponíveis para callbacks WinForms
                    // disparados depois que a construção inicial da janela terminou.
                    ps.AddScript(". '" + escapedScriptPath + "'");
                    ps.Invoke();

                    if (ps.InvocationStateInfo != null && ps.InvocationStateInfo.State == PSInvocationState.Failed)
                    {
                        string message = ps.InvocationStateInfo.Reason != null
                            ? ps.InvocationStateInfo.Reason.Message
                            : "A execução interna da Central foi encerrada com falha.";
                        ShowFatal(message);
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
    }

    private static void ApplyShellIdentity()
    {
        try
        {
            SetCurrentProcessExplicitAppUserModelID(AppUserModelId);
        }
        catch
        {
            // A identidade explícita melhora agrupamento/fixação na barra de tarefas,
            // mas nunca deve impedir a abertura da Central em Windows incompatível.
        }
    }

    private static int RunSelfTest(string appRoot)
    {
        try
        {
            string[] requiredFiles =
            {
                "Central de Trabalho.ps1",
                @"Atualizador\CANAIS.json",
                @"Atualizador\Central de Trabalho Updater.exe",
                @"Atualizador\Central de Trabalho Updater.ps1",
                @"Atualizador\Update.Core.ps1",
                @"Modulos\Central-de-Manutencao-CB5\Central Manutencao CB5.ps1",
                @"Modulos\Central-de-Manutencao-CB5\Manutencao.Core.ps1",
                @"Modulos\Gerador-de-Planilhas-CB5-TV5\Gerador Planilhas.ps1",
                @"Modulos\Gerador-de-Planilhas-CB5-TV5\Componentes.Core.ps1",
                @"Modulos\Controle-NF-Entrada\Controle NF Entrada.ps1",
                @"Modulos\Controle-NF-Entrada\NFEntrada.Core.ps1"
            };

            foreach (string relativePath in requiredFiles)
            {
                string fullPath = Path.Combine(appRoot, relativePath);
                if (!File.Exists(fullPath) || new FileInfo(fullPath).Length <= 0)
                {
                    return 10;
                }
            }

            foreach (string script in Directory.GetFiles(appRoot, "*.ps1", SearchOption.AllDirectories))
            {
                System.Management.Automation.Language.Token[] tokens;
                System.Management.Automation.Language.ParseError[] errors;
                System.Management.Automation.Language.Parser.ParseFile(script, out tokens, out errors);
                if (errors != null && errors.Length > 0)
                {
                    return 11;
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
                        return 12;
                    }
                }
            }

            return 0;
        }
        catch
        {
            return 13;
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

    private static void ShowFatal(string details)
    {
        string message = "Não foi possível iniciar a Central de Trabalho.";
        if (!string.IsNullOrWhiteSpace(details))
        {
            message += "\r\n\r\n" + details;
        }

        MessageBox.Show(
            message,
            "Central de Trabalho",
            MessageBoxButtons.OK,
            MessageBoxIcon.Error);
    }
}

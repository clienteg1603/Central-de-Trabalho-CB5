using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        string appRoot = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string scriptPath = Path.Combine(appRoot, "Central de Trabalho.ps1");

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
                    ps.AddScript("& '" + escapedScriptPath + "'");
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

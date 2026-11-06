using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace PcOptimizerPortable
{
    internal static class Program
    {
        private const string LauncherScript = "Iniciar-PC-Optimizer.ps1";
        private const string ApplicationName = "PC Optimizer Portable";

        [STAThread]
        private static int Main(string[] args)
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(root, LauncherScript);
            bool silent = HasArgument(args, "-SelfTest") || HasArgument(args, "-ValidateUI") ||
                          HasArgument(args, "--self-test") || HasArgument(args, "--validate-ui");

            if (!File.Exists(scriptPath))
            {
                ShowError(
                    "O pacote do PC Optimizer está incompleto.",
                    "Extraia novamente o ZIP completo e execute o PC-Optimizer.exe a partir da pasta extraída.",
                    silent);
                return 2;
            }

            if (!silent && ShouldAutoElevate(args) && !IsAdministrator())
            {
                return ElevateCurrentProcess(root, args, silent);
            }

            string powerShell = FindPowerShell();
            if (string.IsNullOrEmpty(powerShell))
            {
                ShowError(
                    "PowerShell não encontrado.",
                    "O Windows 10/11 inclui o Windows PowerShell 5.1. Reative-o ou instale o PowerShell 7.",
                    silent);
                return 3;
            }

            List<string> arguments = new List<string>();
            arguments.Add("-NoLogo");
            arguments.Add("-NoProfile");
            arguments.Add("-STA");
            arguments.Add("-ExecutionPolicy");
            arguments.Add("Bypass");
            arguments.Add("-File");
            arguments.Add(scriptPath);
            arguments.AddRange(args);

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = powerShell;
            startInfo.Arguments = BuildArguments(arguments);
            startInfo.WorkingDirectory = root;
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;
            startInfo.EnvironmentVariables["PC_OPTIMIZER_LAUNCHER"] = "exe";
            startInfo.EnvironmentVariables["PC_OPTIMIZER_HOME"] = root;

            try
            {
                using (Process process = Process.Start(startInfo))
                {
                    Task<string> outputTask = process.StandardOutput.ReadToEndAsync();
                    Task<string> errorTask = process.StandardError.ReadToEndAsync();
                    process.WaitForExit();

                    string output = outputTask.Result;
                    string error = errorTask.Result;
                    WriteLauncherLog(root, output, error);

                    if (process.ExitCode != 0 && !silent)
                    {
                        ShowError(
                            "O PC Optimizer foi encerrado com erro.",
                            "Código: " + process.ExitCode + Environment.NewLine +
                            "Consulte Dados\\Logs\\portable-launcher.log para detalhes.",
                            false);
                    }

                    return process.ExitCode;
                }
            }
            catch (Exception ex)
            {
                WriteLauncherLog(root, string.Empty, ex.ToString());
                if (!silent)
                {
                    ShowError(
                        "Não foi possível iniciar o PC Optimizer.",
                        ex.Message + Environment.NewLine +
                        "Consulte Dados\\Logs\\portable-launcher.log para detalhes.",
                        false);
                }
                return 1;
            }
        }

        private static bool IsAdministrator()
        {
            try
            {
                using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
                {
                    WindowsPrincipal principal = new WindowsPrincipal(identity);
                    return principal.IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch
            {
                return false;
            }
        }

        private static bool ShouldAutoElevate(string[] args)
        {
            if (string.Equals(Environment.GetEnvironmentVariable("PC_OPTIMIZER_ELEVATED"), "1", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
            if (string.Equals(Environment.GetEnvironmentVariable("PC_OPTIMIZER_NO_ELEVATE"), "1", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
            return !HasArgument(args, "--no-elevate");
        }

        private static int ElevateCurrentProcess(string root, string[] args, bool silent)
        {
            try
            {
                ProcessStartInfo elevateInfo = new ProcessStartInfo();
                elevateInfo.FileName = Process.GetCurrentProcess().MainModule.FileName;
                elevateInfo.Arguments = BuildArguments(new List<string>(args));
                elevateInfo.WorkingDirectory = root;
                elevateInfo.UseShellExecute = true;
                elevateInfo.Verb = "runas";
                elevateInfo.EnvironmentVariables["PC_OPTIMIZER_ELEVATED"] = "1";
                using (Process elevated = Process.Start(elevateInfo))
                {
                }
                return 0;
            }
            catch (Exception ex)
            {
                WriteLauncherLog(root, string.Empty, ex.ToString());
                ShowError(
                    "Elevação cancelada ou indisponível.",
                    "O PC Optimizer foi configurado para abrir como administrador. A elevação foi cancelada ou bloqueada pela política do Windows segurança." + Environment.NewLine +
                    "Use PC-Optimizer.exe --no-elevate para abrir sem elevação.",
                    silent);
                return 1;
            }
        }

        private static string FindPowerShell()
        {
            string systemRoot = Environment.GetFolderPath(Environment.SpecialFolder.System);
            if (!string.IsNullOrEmpty(systemRoot))
            {
                string windowsPowerShell = Path.Combine(
                    systemRoot,
                    "WindowsPowerShell",
                    "v1.0",
                    "powershell.exe");
                if (File.Exists(windowsPowerShell))
                {
                    return windowsPowerShell;
                }
            }

            try
            {
                ProcessStartInfo probe = new ProcessStartInfo();
                probe.FileName = "pwsh.exe";
                probe.Arguments = "-NoLogo -NoProfile -Command $true";
                probe.WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory;
                probe.UseShellExecute = false;
                probe.CreateNoWindow = true;
                probe.WindowStyle = ProcessWindowStyle.Hidden;

                using (Process process = Process.Start(probe))
                {
                    process.WaitForExit(5000);
                    if (!process.HasExited)
                    {
                        process.Kill();
                    }
                    else if (process.ExitCode == 0)
                    {
                        return "pwsh.exe";
                    }
                }
            }
            catch
            {
                // Fall through to the explicit Windows PowerShell path check above.
            }

            return null;
        }

        private static bool HasArgument(string[] args, string expected)
        {
            if (args == null)
            {
                return false;
            }

            foreach (string arg in args)
            {
                if (string.Equals(arg, expected, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        private static string BuildArguments(List<string> arguments)
        {
            StringBuilder builder = new StringBuilder();
            foreach (string argument in arguments)
            {
                if (builder.Length > 0)
                {
                    builder.Append(' ');
                }
                builder.Append(QuoteArgument(argument));
            }
            return builder.ToString();
        }

        private static string QuoteArgument(string argument)
        {
            if (string.IsNullOrEmpty(argument))
            {
                return "\"\"";
            }

            if (argument.IndexOfAny(new[] { ' ', '\t', '"' }) < 0)
            {
                return argument;
            }

            StringBuilder builder = new StringBuilder();
            builder.Append('"');
            int backslashes = 0;

            foreach (char value in argument)
            {
                if (value == '\\')
                {
                    backslashes++;
                    continue;
                }

                if (value == '"')
                {
                    builder.Append('\\', backslashes * 2 + 1);
                    builder.Append('"');
                    backslashes = 0;
                    continue;
                }

                builder.Append('\\', backslashes);
                builder.Append(value);
                backslashes = 0;
            }

            builder.Append('\\', backslashes * 2);
            builder.Append('"');
            return builder.ToString();
        }

        private static void WriteLauncherLog(string root, string output, string error)
        {
            try
            {
                string dataDirectory = Path.Combine(root, "Dados");
                string logDirectory = Path.Combine(dataDirectory, "Logs");
                if (!Directory.Exists(logDirectory))
                {
                    Directory.CreateDirectory(logDirectory);
                }

                string logPath = Path.Combine(logDirectory, "portable-launcher.log");
                using (StreamWriter writer = new StreamWriter(logPath, true, Encoding.UTF8))
                {
                    writer.WriteLine("[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] PC Optimizer launcher (exe)");
                    if (!string.IsNullOrWhiteSpace(output))
                    {
                        writer.WriteLine(output.TrimEnd());
                    }
                    if (!string.IsNullOrWhiteSpace(error))
                    {
                        writer.WriteLine(error.TrimEnd());
                    }
                }
            }
            catch
            {
                // Logging must never prevent the application from starting.
            }
        }

        private static void ShowError(string title, string message, bool silent)
        {
            if (silent)
            {
                return;
            }

            MessageBox.Show(
                message,
                ApplicationName + " - " + title,
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}

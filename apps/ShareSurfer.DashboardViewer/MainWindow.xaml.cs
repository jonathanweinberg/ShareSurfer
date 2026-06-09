using Microsoft.Web.WebView2.Core;
using Microsoft.Win32;
using System.IO;
using System.Windows;

namespace ShareSurfer.DashboardViewer;

public partial class MainWindow : Window
{
    private DashboardPackage? _currentPackage;

    public MainWindow()
    {
        InitializeComponent();
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e)
    {
        await InitializeWebViewAsync();

        var args = Environment.GetCommandLineArgs();
        if (args.Length > 1)
        {
            TryOpenDashboard(args[1]);
        }
    }

    private async Task InitializeWebViewAsync()
    {
        var userDataPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ShareSurfer",
            "DashboardViewer",
            "WebView2");

        Directory.CreateDirectory(userDataPath);
        var environment = await CoreWebView2Environment.CreateAsync(null, userDataPath);
        await DashboardView.EnsureCoreWebView2Async(environment);

        DashboardView.CoreWebView2.Settings.AreDevToolsEnabled = false;
        DashboardView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
        DashboardView.CoreWebView2.Settings.AreHostObjectsAllowed = false;
        DashboardView.CoreWebView2.Settings.IsWebMessageEnabled = false;
        DashboardView.CoreWebView2.NavigationStarting += BlockExternalNavigation;
    }

    private void OpenDashboard_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Open ShareSurfer dashboard index.html",
            Filter = "ShareSurfer dashboard (index.html)|index.html|HTML files (*.html)|*.html|All files (*.*)|*.*",
            CheckFileExists = true,
            Multiselect = false
        };

        if (dialog.ShowDialog(this) == true)
        {
            TryOpenDashboard(dialog.FileName);
        }
    }

    private void Reload_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPackage is null)
        {
            SetStatus("No dashboard is loaded.");
            return;
        }

        DashboardView.Reload();
        SetStatus($"Reloaded {_currentPackage.DisplayPath}");
    }

    private void TryOpenDashboard(string path)
    {
        try
        {
            var package = DashboardPackage.Open(path);
            _currentPackage = package;
            DashboardView.Source = new Uri(package.IndexPath);
            SetStatus(package.StatusMessage);
        }
        catch (Exception ex)
        {
            SetStatus(ex.Message);
            MessageBox.Show(this, ex.Message, "ShareSurfer dashboard could not be opened", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private static void BlockExternalNavigation(object? sender, CoreWebView2NavigationStartingEventArgs e)
    {
        if (!Uri.TryCreate(e.Uri, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeFile)
        {
            e.Cancel = true;
        }
    }

    private void SetStatus(string message)
    {
        StatusText.Text = message;
    }
}

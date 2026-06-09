using System.IO;
using System.Security.Cryptography;
using System.Text.Json;

namespace ShareSurfer.DashboardViewer;

public sealed record DashboardPackage(
    string RootPath,
    string IndexPath,
    string DataScriptPath,
    string ManifestPath,
    string DisplayPath,
    string StatusMessage)
{
    public static DashboardPackage Open(string path)
    {
        var candidate = Path.GetFullPath(path);
        var root = File.Exists(candidate)
            ? Path.GetDirectoryName(candidate) ?? throw new InvalidOperationException("Dashboard file has no parent folder.")
            : candidate;

        var indexPath = Path.Combine(root, "index.html");
        var dataScriptPath = Path.Combine(root, "sharesurfer-data.js");
        var manifestPath = Path.Combine(root, "dashboard-manifest.json");

        RequireFile(indexPath, "index.html");
        RequireFile(dataScriptPath, "sharesurfer-data.js");
        RequireFile(manifestPath, "dashboard-manifest.json");

        var manifest = DashboardManifest.Load(manifestPath);
        var indexHash = ShortSha256(indexPath);
        var dataHash = ShortSha256(dataScriptPath);
        var displayRoot = Path.GetFileName(root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
        var status = $"Loaded {displayRoot}. Generated: {manifest.GeneratedAt}. Rows: {manifest.RowSummary}. Evidence: index {indexHash}, data {dataHash}.";

        return new DashboardPackage(
            root,
            new Uri(indexPath).AbsoluteUri,
            dataScriptPath,
            manifestPath,
            root,
            status);
    }

    private static void RequireFile(string path, string name)
    {
        if (!File.Exists(path))
        {
            throw new FileNotFoundException($"This does not look like a ShareSurfer standalone dashboard. Missing {name}.", path);
        }
    }

    private static string ShortSha256(string path)
    {
        using var stream = File.OpenRead(path);
        var hash = SHA256.HashData(stream);
        return Convert.ToHexString(hash).Substring(0, 12);
    }
}

internal sealed record DashboardManifest(string GeneratedAt, string RowSummary)
{
    public static DashboardManifest Load(string path)
    {
        using var stream = File.OpenRead(path);
        using var document = JsonDocument.Parse(stream);
        var root = document.RootElement;
        var generatedAt = TryGetString(root, "generatedAt", "unknown");
        var rowSummary = TryGetRowSummary(root);
        return new DashboardManifest(generatedAt, rowSummary);
    }

    private static string TryGetString(JsonElement element, string propertyName, string fallback)
    {
        return element.TryGetProperty(propertyName, out var property) && property.ValueKind == JsonValueKind.String
            ? property.GetString() ?? fallback
            : fallback;
    }

    private static string TryGetRowSummary(JsonElement root)
    {
        if (!root.TryGetProperty("rowCounts", out var rowCounts) || rowCounts.ValueKind != JsonValueKind.Object)
        {
            return "row counts unavailable";
        }

        var parts = rowCounts.EnumerateObject()
            .Take(5)
            .Select(property => $"{property.Name}={property.Value}")
            .ToArray();

        return parts.Length == 0 ? "row counts unavailable" : string.Join(", ", parts);
    }
}

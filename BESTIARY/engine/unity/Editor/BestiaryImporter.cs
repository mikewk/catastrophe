// BESTIARY sheet importer for Unity 2021.3 LTS and newer.
//
// THIS IS AN EDITOR SCRIPT. It ships inside a folder called "Editor", which is how
// Unity is told to compile a file into the editor assembly only and leave it out of
// player builds -- `using UnityEditor;` in a player assembly is a hard CS0246 and
// would break your first build. It is ALSO wrapped in #if UNITY_EDITOR, so it stays
// out of a player build even if you move it somewhere that is not an Editor folder.
// Keep it in an Editor folder anyway; that is the part Unity actually documents.
//
// Use Tools > BESTIARY. It configures every pack texture the way pixel art needs:
//
//     Filter Mode        Point (nearest neighbour)
//     Mip Maps           off
//     Compression        Uncompressed, RGBA32 -- no DXT/ASTC blocking on hard edges
//     Alpha Is Transparency  on  (the frames are binary alpha)
//     Mesh Type          Full Rect -- tight meshes crop transparent edges and break
//                        alignment between frames
//     Wrap Mode          Clamp
//     Pixels Per Unit    the cell size, so one cell is one world unit
//
// The cell size is NOT hardcoded. Every sheet in this pack is a single horizontal
// strip of square cells, so the importer reads width and height straight out of the
// PNG header and derives cell = height, frames = width / height. Checked against all
// 530 files: 32 and 48 px cells in sheets/, 64 and 96 px in sheets_2x/.
//
// The pack LOCATION is not hardcoded either. PackRoot() looks for "Assets/BESTIARY",
// then "Assets/Resources/BESTIARY", then any folder named BESTIARY anywhere under
// Assets/ that holds both sheets/ and creatures.json, and logs the one it used. So
// the same menu item works whether you dropped the pack straight into Assets/ or
// under Assets/Resources/ for BestiaryAnimator.LoadFromResources(). There are no
// consts to edit.
//
// Re-running is safe: existing sprite GUIDs are reused, so references from your
// scenes and prefabs survive a reimport.

#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.U2D.Sprites;
using UnityEngine;

public static class BestiaryImporter
{
    /// <summary>The folder name inside the download. Do not rename the folder.</summary>
    public const string PackFolderName = "BESTIARY";
    /// <summary>Checked first, then ResourcesPackFolder, then a search under Assets/.</summary>
    public const string DefaultPackFolder = "Assets/BESTIARY";
    public const string ResourcesPackFolder = "Assets/Resources/BESTIARY";
    public const string AssetsRoot = "Assets";

    static string _root;

    /// <summary>True if `folder` really is this pack: it holds sheets/ and creatures.json.</summary>
    public static bool IsPackFolder(string folder)
    {
        return !string.IsNullOrEmpty(folder)
            && Directory.Exists(folder + "/sheets")
            && File.Exists(folder + "/creatures.json");
    }

    /// <summary>Where the pack actually is, or null. Cached until the folder moves.</summary>
    public static string PackRoot()
    {
        if (IsPackFolder(_root)) return _root;
        _root = null;
        if (IsPackFolder(DefaultPackFolder)) return _root = DefaultPackFolder;
        if (IsPackFolder(ResourcesPackFolder)) return _root = ResourcesPackFolder;
        if (!Directory.Exists(AssetsRoot)) return null;
        var hits = Directory.GetDirectories(AssetsRoot, PackFolderName,
                                            SearchOption.AllDirectories);
        Array.Sort(hits, StringComparer.Ordinal);
        for (int i = 0; i < hits.Length; i++)
        {
            string p = hits[i].Replace('\\', '/');
            if (IsPackFolder(p)) return _root = p;
        }
        return null;
    }

    /// <summary>PackRoot(), or null plus one error saying exactly what to do.</summary>
    static string RequirePackRoot()
    {
        string root = PackRoot();
        if (root == null)
            Debug.LogError($"BESTIARY: could not find the pack under {AssetsRoot}/. Copy the " +
                           $"'BESTIARY' folder out of the download into Assets/ (keeping its " +
                           "name) so that Assets/BESTIARY/sheets and " +
                           "Assets/BESTIARY/creatures.json exist, then run this again.");
        return root;
    }

    public static string SheetsFolder { get { return PackRoot() + "/sheets"; } }
    public static string Sheets2xFolder { get { return PackRoot() + "/sheets_2x"; } }
    public static string FramesFolder { get { return PackRoot() + "/frames"; } }

    [MenuItem("Tools/BESTIARY/Import sheets  (slice + Point + no compression)")]
    public static void ImportSheets()
    {
        string root = RequirePackRoot();
        if (root == null) return;
        Debug.Log($"BESTIARY: using the pack at {root}");
        int n = ImportFolder(root + "/sheets", true)
              + ImportFolder(root + "/sheets_2x", true);
        Debug.Log($"BESTIARY: sliced and configured {n} sheet(s).");
    }

    [MenuItem("Tools/BESTIARY/Import loose frames  (Point + no compression)")]
    public static void ImportLooseFrames()
    {
        string root = RequirePackRoot();
        if (root == null) return;
        int n = ImportFolder(root + "/frames", false);
        Debug.Log($"BESTIARY: configured {n} loose frame(s).");
    }

    /// <summary>
    /// Fill every selected BestiaryAnimator's `clips` from the sliced sheets, using
    /// each one's creatureId. This is the no-Resources path: the sprite references
    /// are serialised into your scene or prefab, so they survive into a build with
    /// nothing under Assets/Resources/.
    /// </summary>
    [MenuItem("Tools/BESTIARY/Fill selected BestiaryAnimator clips from the pack")]
    public static void FillSelectedAnimators()
    {
        string root = RequirePackRoot();
        if (root == null) return;
        var sel = Selection.gameObjects;
        int seen = 0, done = 0;
        for (int i = 0; i < sel.Length; i++)
        {
            var anim = sel[i].GetComponent<BestiaryAnimator>();
            if (anim == null) continue;
            seen++;
            if (FillFromPack(anim, root)) done++;
        }
        if (seen == 0)
            Debug.LogWarning($"BESTIARY: select one or more GameObjects that have a " +
                             "BestiaryAnimator component, then run this again.");
        else
            Debug.Log($"BESTIARY: filled {done} of {seen} BestiaryAnimator(s) from {root}.");
    }

    [MenuItem("Tools/BESTIARY/Fill selected BestiaryAnimator clips from the pack", true)]
    static bool FillSelectedAnimatorsValidate()
    {
        return Selection.gameObjects.Length > 0;
    }

    /// <summary>Fill one animator's clips from `packRoot`/sheets. Returns false and
    /// says why if the sheets are not sliced yet.</summary>
    public static bool FillFromPack(BestiaryAnimator anim, string packRoot)
    {
        if (anim == null || string.IsNullOrEmpty(anim.creatureId)) return false;
        var built = new List<BestiaryAnimator.Clip>();
        int missing = 0;
        foreach (var state in BestiaryAnimator.States)
        {
            string path = $"{packRoot}/sheets/{anim.creatureId}_{state}.png";
            if (!File.Exists(path)) { missing++; continue; }
            var sprites = new List<Sprite>();
            foreach (var o in AssetDatabase.LoadAllAssetsAtPath(path))
            {
                var s = o as Sprite;
                if (s != null) sprites.Add(s);
            }
            if (sprites.Count == 0) continue;
            sprites.Sort((a, b) => string.CompareOrdinal(a.name, b.name));
            built.Add(new BestiaryAnimator.Clip
            {
                state = state,
                frames = sprites.ToArray(),
                fps = BestiaryAnimator.PackFps,
                loop = BestiaryAnimator.Loops(state),
            });
        }
        if (missing == BestiaryAnimator.States.Length)
        {
            Debug.LogWarning($"BESTIARY: no sheets for creatureId '{anim.creatureId}' under " +
                             $"{packRoot}/sheets. Check the spelling against creatures.json.",
                             anim);
            return false;
        }
        if (built.Count == 0)
        {
            Debug.LogWarning($"BESTIARY: the sheets for '{anim.creatureId}' have no sprites yet. " +
                             "Run Tools > BESTIARY > Import sheets first -- it slices each strip " +
                             "into its frames.", anim);
            return false;
        }
        anim.clips = built;
        EditorUtility.SetDirty(anim);
        return true;
    }

    static int ImportFolder(string folder, bool slice)
    {
        if (!Directory.Exists(folder))
        {
            Debug.LogWarning($"BESTIARY: no folder at {folder} -- nothing to do.");
            return 0;
        }
        var files = Directory.GetFiles(folder, "*.png", SearchOption.AllDirectories);
        Array.Sort(files, StringComparer.Ordinal);

        int done = 0;
        try
        {
            for (int i = 0; i < files.Length; i++)
            {
                string assetPath = files[i].Replace('\\', '/');
                if (EditorUtility.DisplayCancelableProgressBar(
                        "BESTIARY import", assetPath, (float)i / files.Length)) break;
                if (Configure(assetPath, slice)) done++;
            }
        }
        finally
        {
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
        }
        return done;
    }

    /// <summary>Apply the pixel-art import settings, and slice if it is a strip.</summary>
    public static bool Configure(string assetPath, bool slice)
    {
        var importer = AssetImporter.GetAtPath(assetPath) as TextureImporter;
        if (importer == null) return false;

        int w, h;
        if (!ReadPngSize(assetPath, out w, out h))
        {
            Debug.LogWarning($"BESTIARY: cannot read PNG header of {assetPath}");
            return false;
        }

        // Square cells in a single row: the cell is the image height.
        int cell = h;
        int count = 1;
        if (slice)
        {
            if (w % h != 0)
            {
                Debug.LogWarning(
                    $"BESTIARY: {assetPath} is {w}x{h}; width is not a whole number of " +
                    "square cells, importing as a single sprite.");
                slice = false;
            }
            else count = w / h;
        }

        var s = new TextureImporterSettings();
        importer.ReadTextureSettings(s);
        s.textureType = TextureImporterType.Sprite;
        s.spriteMode = (int)(slice ? SpriteImportMode.Multiple : SpriteImportMode.Single);
        s.spritePixelsPerUnit = cell;
        s.spriteMeshType = SpriteMeshType.FullRect;
        s.spriteExtrude = 0;
        s.spriteAlignment = (int)SpriteAlignment.Center;
        s.spriteGenerateFallbackPhysicsShape = false;
        s.filterMode = FilterMode.Point;
        s.mipmapEnabled = false;
        s.alphaIsTransparency = true;
        s.alphaSource = TextureImporterAlphaSource.FromInput;
        s.wrapMode = TextureWrapMode.Clamp;
        s.npotScale = TextureImporterNPOTScale.None;
        s.readable = false;
        importer.SetTextureSettings(s);
        importer.spriteImportMode = slice ? SpriteImportMode.Multiple
                                          : SpriteImportMode.Single;
        importer.filterMode = FilterMode.Point;
        importer.mipmapEnabled = false;
        importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.crunchedCompression = false;
        importer.maxTextureSize = 2048;

        var plat = importer.GetDefaultPlatformTextureSettings();
        plat.maxTextureSize = 2048;
        plat.format = TextureImporterFormat.RGBA32;   // explicit: never block-compressed
        plat.textureCompression = TextureImporterCompression.Uncompressed;
        plat.crunchedCompression = false;
        importer.SetPlatformTextureSettings(plat);

        if (slice) SliceStrip(importer, assetPath, cell, count);

        EditorUtility.SetDirty(importer);
        importer.SaveAndReimport();
        return true;
    }

    /// <summary>Cut a horizontal strip into `count` square cells, left to right.</summary>
    static void SliceStrip(TextureImporter importer, string assetPath, int cell, int count)
    {
        string baseName = Path.GetFileNameWithoutExtension(assetPath);

        var factory = new SpriteDataProviderFactories();
        factory.Init();
        var provider = factory.GetSpriteEditorDataProviderFromObject(importer);
        if (provider == null)
        {
            SliceStripLegacy(importer, baseName, cell, count);
            return;
        }
        provider.InitSpriteEditorDataProvider();

        // Reuse the GUID of a sprite with the same name so scene references survive.
        var existing = new Dictionary<string, GUID>();
        foreach (var old in provider.GetSpriteRects()) existing[old.name] = old.spriteID;

        var rects = new SpriteRect[count];
        var pairs = new List<SpriteNameFileIdPair>(count);
        for (int i = 0; i < count; i++)
        {
            string name = $"{baseName}_{i:00}";
            GUID id;
            if (!existing.TryGetValue(name, out id)) id = GUID.Generate();
            rects[i] = new SpriteRect
            {
                name = name,
                spriteID = id,
                // One row, so y is 0 whichever way up the texture origin is.
                rect = new Rect(i * cell, 0, cell, cell),
                alignment = SpriteAlignment.Center,
                pivot = new Vector2(0.5f, 0.5f),
                border = Vector4.zero,
            };
            pairs.Add(new SpriteNameFileIdPair(name, id));
        }
        provider.SetSpriteRects(rects);

        var names = provider.GetDataProvider<ISpriteNameFileIdDataProvider>();
        if (names != null) names.SetNameFileIdPairs(pairs);
        provider.Apply();
    }

    /// <summary>Fallback for projects without the com.unity.2d.sprite package.</summary>
#pragma warning disable 0618
    static void SliceStripLegacy(TextureImporter importer, string baseName,
                                 int cell, int count)
    {
        var meta = new SpriteMetaData[count];
        for (int i = 0; i < count; i++)
        {
            meta[i] = new SpriteMetaData
            {
                name = $"{baseName}_{i:00}",
                rect = new Rect(i * cell, 0, cell, cell),
                alignment = (int)SpriteAlignment.Center,
                pivot = new Vector2(0.5f, 0.5f),
            };
        }
        importer.spritesheet = meta;
    }
#pragma warning restore 0618

    /// <summary>Width and height straight out of the PNG IHDR chunk.</summary>
    public static bool ReadPngSize(string path, out int width, out int height)
    {
        width = height = 0;
        try
        {
            using (var fs = File.OpenRead(path))
            {
                var b = new byte[24];
                if (fs.Read(b, 0, 24) != 24) return false;
                if (b[0] != 0x89 || b[1] != 'P' || b[2] != 'N' || b[3] != 'G') return false;
                if (b[12] != 'I' || b[13] != 'H' || b[14] != 'D' || b[15] != 'R') return false;
                width = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
                height = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
            }
        }
        catch (IOException e)
        {
            Debug.LogWarning($"BESTIARY: {path}: {e.Message}");
            return false;
        }
        return width > 0 && height > 0;
    }
}
#endif

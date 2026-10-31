// BESTIARY creature animator for Unity 2021.3 LTS and newer.
//
// This is a RUNTIME script -- it touches nothing in UnityEditor, so it belongs
// anywhere in Assets/ and compiles into your player build. (Its companion,
// Editor/BestiaryImporter.cs, is editor-only and ships inside an Editor folder.)
//
// Put this on a GameObject with a SpriteRenderer, set `creatureId`, and fill
// `clips`. Three ways to fill them, in order of how most people work:
//
//   1. Pack at Assets/BESTIARY/ -- select the GameObject and run
//      Tools > BESTIARY > Fill selected BestiaryAnimator clips from the pack. The
//      sprite references are serialised into your scene or prefab, so they work in
//      a build with no Resources folder. This is the recommended path.
//   2. Pack at Assets/Resources/BESTIARY/ -- call LoadFromResources() at runtime.
//      Convenient, but everything under Resources/ is force-built into your player.
//   3. Drag the sliced sprites into `clips` by hand, one Clip per state.
//
// All three need the sheets sliced first: Tools > BESTIARY > Import sheets. That also
// puts the textures on Point filter with no compression -- see BestiaryImporter.cs.
//
// The pack's own numbers, baked in as defaults: 10 fps; idle and move loop;
// attack, hit and death play once.

using System;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(SpriteRenderer))]
[AddComponentMenu("BESTIARY/Bestiary Animator")]
public class BestiaryAnimator : MonoBehaviour
{
    /// <summary>The five states every creature in the pack ships.</summary>
    public static readonly string[] States = { "idle", "move", "attack", "hit", "death" };
    public const float PackFps = 10f;
    /// <summary>Default sub-path under a Resources folder: Resources/BESTIARY/sheets.</summary>
    public const string DefaultResourcesRoot = "BESTIARY/sheets";

    /// <summary>True for the two states that loop, false for the three that play once.</summary>
    public static bool Loops(string state) { return state == "idle" || state == "move"; }

    [Serializable]
    public class Clip
    {
        public string state = "idle";
        public Sprite[] frames = new Sprite[0];
        public float fps = PackFps;
        public bool loop = false;
    }

    [Tooltip("An id from creatures.json, e.g. \"slime_green\". Used by " +
             "Tools > BESTIARY > Fill selected BestiaryAnimator clips, and by " +
             "LoadFromResources() when you call it with no argument.")]
    public string creatureId = "slime_green";
    [Tooltip("One entry per state. Frames must be in play order.")]
    public List<Clip> clips = new List<Clip>();
    public string startState = "idle";
    [Tooltip("Return to idle when attack or hit finishes. death holds its last frame.")]
    public bool autoReturnToIdle = true;
    public bool playOnEnable = true;

    /// <summary>Fires when a non-looping state reaches its last frame.</summary>
    public event Action<string> StateFinished;
    public event Action Died;

    public string State { get { return _clip != null ? _clip.state : null; } }
    public bool IsPlaying { get { return _playing; } }
    public bool IsDead { get { return _clip != null && _clip.state == "death" && !_playing; } }

    SpriteRenderer _sr;
    Clip _clip;
    int _frame;
    float _t;
    bool _playing;

    void Awake()
    {
        _sr = GetComponent<SpriteRenderer>();
    }

    void OnEnable()
    {
        // Nothing to play until clips exist -- LoadFromResources() starts it instead.
        if (playOnEnable && clips.Count > 0) Play(startState);
    }

    public Clip GetClip(string state)
    {
        for (int i = 0; i < clips.Count; i++)
            if (clips[i] != null && clips[i].state == state && clips[i].frames.Length > 0)
                return clips[i];
        return null;
    }

    /// <summary>Play a state by name: idle, move, attack, hit or death.</summary>
    public bool Play(string state)
    {
        var c = GetClip(state);
        if (c == null)
        {
            Debug.LogWarning($"BESTIARY: no clip for state '{state}' on {name}", this);
            return false;
        }
        _clip = c;
        _frame = 0;
        _t = 0f;
        _playing = true;
        if (_sr == null) _sr = GetComponent<SpriteRenderer>();
        _sr.enabled = true;
        _sr.sprite = c.frames[0];
        return true;
    }

    public void Idle() { Play("idle"); }
    public void Move() { Play("move"); }
    public void Attack() { Play("attack"); }
    public void Hurt() { Play("hit"); }
    public void Die() { Play("death"); }

    public void Stop() { _playing = false; }

    void Update()
    {
        if (!_playing || _clip == null || _clip.fps <= 0f) return;
        _t += Time.deltaTime;
        float step = 1f / _clip.fps;
        while (_t >= step)
        {
            _t -= step;
            _frame++;
            if (_frame >= _clip.frames.Length)
            {
                if (_clip.loop)
                {
                    _frame = 0;
                }
                else
                {
                    _frame = _clip.frames.Length - 1;
                    _playing = false;
                    _sr.sprite = _clip.frames[_frame];
                    string done = _clip.state;
                    if (StateFinished != null) StateFinished(done);
                    if (done == "death")
                    {
                        if (Died != null) Died();
                        return;
                    }
                    if (autoReturnToIdle) Play("idle");
                    return;
                }
            }
            _sr.sprite = _clip.frames[_frame];
        }
    }

    /// <summary>Build `clips` for the inspector's `creatureId`. See the overload.</summary>
    public bool LoadFromResources() { return LoadFromResources(creatureId); }

    /// <summary>
    /// Build `clips` from sliced sheets under a Resources folder. This ONLY works if
    /// the pack -- or at least its sheets/ folder -- sits under Assets/Resources/, so
    /// that Assets/Resources/BESTIARY/sheets/&lt;id&gt;_&lt;state&gt;.png exists;
    /// Resources.LoadAll cannot see Assets/BESTIARY/. If the pack is at
    /// Assets/BESTIARY/ instead, leave this alone and use
    /// Tools > BESTIARY > Fill selected BestiaryAnimator clips from the pack.
    /// Expects the sprite names the importer generates: &lt;creature&gt;_&lt;state&gt;_00.
    /// Returns false AND logs why, rather than failing silently.
    /// </summary>
    public bool LoadFromResources(string id, string resourcesRoot = DefaultResourcesRoot)
    {
        clips.Clear();
        if (string.IsNullOrEmpty(id))
        {
            Debug.LogWarning($"BESTIARY: LoadFromResources needs a creatureId.", this);
            return false;
        }
        foreach (var st in States)
        {
            var sprites = Resources.LoadAll<Sprite>($"{resourcesRoot}/{id}_{st}");
            if (sprites == null || sprites.Length == 0) continue;
            Array.Sort(sprites, (a, b) => string.CompareOrdinal(a.name, b.name));
            clips.Add(new Clip
            {
                state = st,
                frames = sprites,
                fps = PackFps,
                loop = Loops(st),
            });
        }
        if (clips.Count == 0)
        {
            Debug.LogWarning(
                $"BESTIARY: nothing loaded for '{id}'. Resources.LoadAll only sees assets " +
                $"under Assets/Resources/, so it looked for " +
                $"Assets/Resources/{resourcesRoot}/{id}_idle.png and friends. Either move " +
                $"the pack to Assets/Resources/BESTIARY/, or -- if it is at Assets/BESTIARY/ -- " +
                "use Tools > BESTIARY > Fill selected BestiaryAnimator clips from the pack " +
                "instead. Either way the sheets must be sliced first with " +
                "Tools > BESTIARY > Import sheets.", this);
            return false;
        }
        if (playOnEnable && _clip == null) Play(startState);
        return true;
    }
}

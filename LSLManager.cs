using UnityEngine;
using LSL;

public class LSLManager : MonoBehaviour
{
    public static LSLManager Instance { get; private set; }

    [Header("Stream Settings")]
    public string StreamName = "GameEvents";  // Name of the LSL stream
    public string StreamType = "Markers";    // Type of the stream
    public int ChannelCount = 1;             // Number of channels

    private StreamInfo streamInfo;
    private StreamOutlet streamOutlet;

    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject); // Persist across scenes
            InitializeLSL();
        }
        else
        {
            Destroy(gameObject);
        }
    }

    private void InitializeLSL()
    {
        try
        {
            streamInfo = new StreamInfo(StreamName, StreamType, ChannelCount, 0, channel_format_t.cf_string, "unity123");
            streamOutlet = new StreamOutlet(streamInfo);
            Debug.Log($"LSL Outlet initialized: {StreamName} ({StreamType})");
        }
        catch (System.Exception ex)
        {
            Debug.LogError($"Failed to initialize LSL Outlet: {ex.Message}");
        }
    }

    public void PushEvent(string eventMarker)
    {
        if (streamOutlet != null)
        {
            streamOutlet.push_sample(new string[] { eventMarker });
            Debug.Log($"Event pushed: {eventMarker}");
        }
        else
        {
            Debug.LogWarning("Attempted to push event, but the outlet is not initialized.");
        }
    }
}

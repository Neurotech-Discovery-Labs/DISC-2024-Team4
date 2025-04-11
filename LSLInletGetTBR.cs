using UnityEngine;
using System.Collections; //JS: for data structures like IEnumerable, List etc.
using System.Collections.Generic; //JS^^
using LSL;

public class LSLInletGetTBR : MonoBehaviour
{
    // We need to find the stream somehow. You must provide a StreamName in editor or before this object is Started.
    public string StreamName; //JS: name of LSL stream to connect to
    ContinuousResolver resolver; //JS: continuously searches for specified stream

    double max_chunk_duration = 0.2;  // Duration, in seconds, of buffer passed to pull_chunk. This must be > than average frame interval.

    // We need to keep track of the inlet once it is resolved ("found")
    private StreamInlet inlet;

    // We need buffers to pass to LSL when pulling data.
    private float[,] data_buffer;  // Note it's a 2D Array, not array of arrays. Each element has to be indexed specifically, no frames/columns.
    private double[] timestamp_buffer; //JS: stores timestamps for each sample
    private float averageTbr; //send this variable to other script

    void Start() //JS: unity calls this once when object initializes
    {
        if (!string.IsNullOrEmpty(StreamName)) 
            resolver = new ContinuousResolver("name", StreamName);
        else
        {
            Debug.LogError("Object must specify a name for resolver to lookup a stream.");
            this.enabled = false; //JS:disables script if no name provided
            return;
        }
        StartCoroutine(ResolveExpectedStream()); //JS: this handles asynchronous stream resolution without freezing game
        
    }

    IEnumerator ResolveExpectedStream() //JS: IEnumerater is a special type in c# to pause and resume execution
    {
        var results = resolver.results(); //JS: var automatically ids type of result, results holds list of streams found
        while (results.Length == 0) //loop will end when at least one stream if found... two though?
        {
            yield return new WaitForSeconds(.1f); //JS: pauses 0.1 seconds or 100 ms before runnign while again, normally check 1000 times per second --> slows game
            results = resolver.results();
        }

        inlet = new StreamInlet(results[0]); //JS: create a new object from the "StreamInlet class", results[0] indicates which stream to connect to
        // Prepare pull_chunk buffer
        int buf_samples = (int)Mathf.Ceil((float)(inlet.info().nominal_srate() * max_chunk_duration));

        // Debug.Log("Allocating buffers to receive " + buf_samples + " samples.");
        int n_channels = inlet.info().channel_count(); //JS: channels = columns in spreadsheet
        data_buffer = new float[buf_samples, n_channels]; //JS: 2d array to store incoming data, samples is the rows
        timestamp_buffer = new double[buf_samples]; //JS: timestamp for when each sample was recorded
    
    }

    public float GetAverageTbr()
    {
        return averageTbr;
    }

    void Update()
    {
        
        if (inlet != null)
        {
            int samples_returned = inlet.pull_chunk(data_buffer, timestamp_buffer);
            //Debug.Log($"Samples returned: {samples_returned} from stream: {StreamName}");

            if (samples_returned > 0)
            {
                //Debug.Log("Number of rows (samples): " + data_buffer.GetLength(0)); 
                //Debug.Log("Number of columns (channels): " + data_buffer.GetLength(1)); 

                int channelCount = data_buffer.GetLength(1); // Number of channels

                // Declare variables outside the loop to persist data across samples 
                    float? channel8Tbr = null; 
                    float? channel9Tbr = null; 

                    for (int sample = 0; sample < samples_returned; sample++) 
                    { 
                        // Get the timestamp for this sample 
                        double timestamp = timestamp_buffer[sample]; 
                        // Access relevant channels 
                        float channel0 = data_buffer[sample, 0]; // Electrode number 
                        float channel2 = data_buffer[sample, 2]; // Theta 
                        float channel4 = data_buffer[sample, 4]; // Beta 
                        // Avoid division by zero when calculating TBR 
                        if (channel4 == 0) continue; 

                        // Calculate Theta/Beta Ratio (TBR) 
                        float tbr = channel2 / channel4; 
                        // Store TBR for electrodes 8 and 9 
                        if (Mathf.Approximately(channel0, 8f)) 
                        { 
                            channel8Tbr = tbr; 
                        } 
                        if (Mathf.Approximately(channel0, 9f)) 
                        { 
                            channel9Tbr = tbr; 
                        } 
                        // Calculate and print average TBR when both values are available 
                        if (channel8Tbr.HasValue && channel9Tbr.HasValue) 
                        { 
                            averageTbr = (channel8Tbr.Value + channel9Tbr.Value) / 2f; 
                            LSLManager.Instance.PushEvent("average TBR" + averageTbr);
                            //Debug.Log($"Average TBR for Channels 8 & 9: {averageTbr:F2}"); 
                            // Reset after calculation to wait for the next pair of samples 
                            channel8Tbr = null; 
                            channel9Tbr = null; 
                        } 
                        /*
                        // Condition: Only print if Channel 0 is 8 or 9 
                        if (Mathf.Approximately(channel0, 8f) || Mathf.Approximately(channel0, 9f)) 
                        { 
                            // print electrode number, theta, beta 
                            string dataLine = $"Sample {sample + 1} (Timestamp: {timestamp}): " + 
                                            $"Channel 0: {channel0}  " + 
                                            $"Channel2/channel4 (TBR): {tbr}"; 
                                            //$"Channel 2: {channel2}  " + 
                                            //$"Channel 4: {channel4}"; 
                            Debug.Log(dataLine); 
                        } 
                        */
                        
                    }
            }
        }
        else
        {
            //Debug.Log("inlet null");
        }
    }
}
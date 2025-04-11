using UnityEngine;
using LSL;
public class ShamControl : MonoBehaviour
{
    public float minStepTime = 5f;
    public float maxStepTime = 15f;
    public float recommendedMin = 6000f;
    public float recommendedMax = 90000f;
    public float brightProbability = 0.6f;
    public float hardMin = 6000f;
    public float hardMax = 130000f;
    public float decayRate = 0.9f; // Decay rate (0 = instant, 1 = no decay)
    public float smoothingFactor = 0.05f; // Lower value = smoother transition
    // public float sineWaveAmplitude = 10000f;
    // public float sineWavePeriod = 300f;
    public float biologicalNoiseLevel = 500f;

    private float currentIntensity;
    private float targetIntensity;
    public Light sunLight;
    private float nextStepTime;
    // LSL Stream
    private LSL.StreamInfo streamInfo;
    private LSL.StreamOutlet streamOutlet;

    private void Start()
    {
        currentIntensity = Random.Range(hardMin, hardMax);
        targetIntensity = currentIntensity;
        SetNextStepTime();

        if (sunLight != null)
        {
            sunLight.intensity = currentIntensity;
        }
    }
    /*
    private void Update()
    {
        // Smoothly transition towards target intensity
        if (Mathf.Abs(sunLight.intensity - targetIntensity) <= 2000f)
        {
            GenerateNewIntensity();
        }

        if (sunLight != null)
        {
            float noiseValue = GaussianRandom(0f, biologicalNoiseLevel);
            float adjustedIntensity = Mathf.Clamp(targetIntensity + noiseValue, hardMin, hardMax);

            // Smoothly transition to the target intensity with smoothing factor
            sunLight.intensity = Mathf.SmoothStep(sunLight.intensity, adjustedIntensity, smoothingFactor);
            LSLManager.Instance.PushEvent($"Intensity: {sunLight.intensity}");
        }
    }
*/
    private void Update()
    {
        // Smoothly transition towards target intensity with decay
        //ApplyDecay();

        if (Time.time >= nextStepTime)
        {
            GenerateNewIntensity();
            SetNextStepTime();
        }

        if (sunLight != null)
        {
            float noiseValue = GaussianRandom(-biologicalNoiseLevel, biologicalNoiseLevel);
            float adjustedIntensity = Mathf.Clamp(targetIntensity + noiseValue, hardMin, hardMax);
            //sunLight.intensity = adjustedIntensity;
            //Debug.Log("adjusted intensity: " + adjustedIntensity);
            sunLight.intensity = Mathf.SmoothStep(sunLight.intensity, adjustedIntensity, smoothingFactor);
            LSLManager.Instance.PushEvent($"Intensity: {sunLight.intensity}");
        }
    }

    private void GenerateNewIntensity()
    {
        float newIntensity;
        if (Random.value < brightProbability)
        {
            newIntensity = Random.Range(recommendedMin, hardMax);
        }
        else
        {
            newIntensity = Random.Range(hardMin, recommendedMin);
        }
        //targetIntensity = Mathf.Clamp(newIntensity, hardMin, hardMax);
        targetIntensity = newIntensity;
        Debug.Log("targetIntensity: " + targetIntensity);
    }

    private void ApplyDecay()
    {
        currentIntensity = currentIntensity * decayRate + targetIntensity * (1 - decayRate);
    }


    private void SetNextStepTime()
    {
        nextStepTime = Time.time + Random.Range(minStepTime, maxStepTime);
        Debug.Log("nextStepTime: " + nextStepTime);
    }

    private float GaussianRandom(float mean, float stdDev)
    {
        float u1 = 1.0f - Random.value;
        float u2 = 1.0f - Random.value;
        float randStdNormal = Mathf.Sqrt(-2.0f * Mathf.Log(u1)) * Mathf.Sin(2.0f * Mathf.PI * u2);
        return mean + stdDev * randStdNormal;
    }
}
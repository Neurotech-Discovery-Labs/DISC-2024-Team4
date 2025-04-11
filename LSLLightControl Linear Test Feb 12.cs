using UnityEngine;
using System.Collections.Generic;
using LSL;
using TMPro;
using UnityEngine.UI; // Import for UI Text
public class LSLLightControlLinearTestFeb12 : MonoBehaviour
{
    // Reference to the directional light
    public LSLInletGetTBR LSLInletGetTBRScript; //AF Changed tp SimpleInlet to get from LSL
    private float? tbr = null; // null to indicate no data yet
    public TbrCalibration TbrCalibrationScript; 
    [SerializeField] private float BaselineConcentratedTbr;   // Minimum TBR value in concentration calibration (adjustable in Inspector)
    [SerializeField] private float BaselineRelaxedTbr;   // Maximum TBR value in relaxation calibration (adjustable in Inspector)
    [Header("calibration TBR mapping to intensity")]
    [SerializeField] private float intensityProportionAtBaselineConcentratedTbr = 0.7f; //proportion of max intensity (ex. 75% brightness) at concentrated Tbr from calibration
    [SerializeField] private float intensityProportionAtBaselineRelaxedTbr = 0.05f; //proportion of max intensity (ex. 25% brightness) at relaxed Tbr from calibration
    public Light directionalLight;
    [Header("Intensity settings")]
    [SerializeField] private float minIntensity = 30000f;      // Minimum light intensity (dark)
    [SerializeField] private float maxIntensity = 90000;  // Maximum light intensity (bright)
    public TextMeshProUGUI tbrAndIntensityText;  // Reference to the UI Text that will display the information
    [SerializeField] private float m; //slope of y = mx+b
    [SerializeField] private float b; //intercept of y = mx+b
    [SerializeField] private float TbrAtMinIntensity;
    [SerializeField] private float TbrAtMaxIntensity;
    private float intensityRange;
    
    void Start()
    {
        if (TbrCalibrationScript != null)
        {
            BaselineConcentratedTbr = TbrCalibrationScript.averageConcentrationTbr;
            BaselineRelaxedTbr = TbrCalibrationScript.averageRelaxationTbr;
        }
        else
        {
            Debug.LogWarning("CalibrationScript reference is missing! Using default values.");
        }
        // Calculate slope (m) and intercept (b) for y = mx + b, where y = % intensity range
        m = (intensityProportionAtBaselineRelaxedTbr - intensityProportionAtBaselineConcentratedTbr) / (BaselineRelaxedTbr - BaselineConcentratedTbr);
        b = intensityProportionAtBaselineConcentratedTbr - m * BaselineConcentratedTbr;
        intensityRange = maxIntensity - minIntensity;
        TbrAtMaxIntensity = (1-b)/m; //smallest tbr where intensity = max
        TbrAtMinIntensity = -b/m; //largest tbr where intensity = 0
        
        //Debugging: Print values to verify correctness 
        Debug.Log ($"TBR Values: Concentrated ({BaselineConcentratedTbr}), Relaxed ({BaselineRelaxedTbr})"); 
        Debug.Log ($"Intensity Proportions ; Concentrated ({intensityProportionAtBaselineConcentratedTbr}), Relaxed ({intensityProportionAtBaselineRelaxedTbr})");
        Debug.Log($"Slope (m): {m}, Intercept (b): {b}");
    }   
    void Update()
    {
        if (LSLInletGetTBRScript != null) // if there is a simpleinlet script
        {
            tbr = LSLInletGetTBRScript.GetAverageTbr();
            //Debug.Log($"Received TBR from LSLEEGInlet: {tbr}");
        }

        // If TBR has been calculated (i.e., not null), we proceed to adjust light intensity
        if (tbr.HasValue && tbr.Value > 0) //AF update incase TBR is zero
        {
            //float clampedTBR = Mathf.Clamp(tbr.Value, tbrMin, tbrMax);
            float proportionIntensityRange = m * tbr.Value + b;  // Compute intensity proportion using y=mx+b
            float mappedIntensity = proportionIntensityRange * intensityRange + minIntensity;
            
            //float mappedIntensity = proportion * maxIntensity;  // Scale to max intensity
            mappedIntensity = Mathf.Clamp(mappedIntensity, minIntensity, maxIntensity); // Ensure valid range
            
            //Debug.Log ("Mapped intensity to TBR");

            // Update the directional light intensity
            if (directionalLight != null)
            {
                directionalLight.intensity = mappedIntensity;
            }

            // Debug log to display the current TBR and the corresponding light intensity
            //Debug.Log("TBR: " + tbr.Value + " | Light Intensity: " + mappedIntensity);

            // Update the UI Text to display TBR and Light Intensity
            if (tbrAndIntensityText != null)
            {
                tbrAndIntensityText.text = "TBR: " + tbr.Value.ToString("F2") + " | Light Intensity: " + mappedIntensity.ToString("F2");
            }
        }
        else
        {
            Debug.LogWarning("TBR is either null or zero. Waiting for valid EEG data...");
            if (tbrAndIntensityText != null)
            {
                 tbrAndIntensityText.text = "Waiting for valid EEG data...";
            }
        }
    }
}
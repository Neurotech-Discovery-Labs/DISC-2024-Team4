using UnityEngine;
using UnityEngine.UI;
using System.Collections;
using System.Collections.Generic;
using TMPro;

public class TbrCalibration : MonoBehaviour
{
    public LSLInletGetTBR tbrScript; // Reference to your LSL script
    public GameObject neurofeedbackGame; // Reference to the neurofeedback game object
    private List<float> relaxationTbrValues = new List<float>(); // Stores TBR values for relaxation
    private List<float> concentrationTbrValues = new List<float>(); // Stores TBR values for concentration
    public float relaxationDuration = 60f; // Calibration time (1 minute)
    public float concentrationDuration = 30f; // Calibration time (1 minute)
    public float WaitSeconds = 0.1f; // Time to wait between readings
    private float relaxationTimerStartTime = 0f; // Time when relaxation calibration starts
    private float concentrationTimerStartTime = 0f; // Time when concentration calibration starts
    private bool isRelaxationRecording = false; // Whether we're currently recording relaxation data
    private bool isConcentrationRecording = false; // Whether we're currently recording concentration data

    public Button startRelaxationButton;
    public TextMeshProUGUI relaxationTbrText; // For displaying relaxation TBR info
    public Button startConcentrationButton;
    public TextMeshProUGUI concentrationTbrText; // For displaying concentration TBR info
    public Button startGameButton; // To start the dolphin game
    public Button gameInstructionsButton;
    public GameObject instructionsPanel;
    [SerializeField] private float relaxationElapsedTime = 0f; // Tracks the elapsed time for relaxation
    [SerializeField] private float concentrationElapsedTime = 0f; // Tracks the elapsed time for concentration
    [SerializeField] private float currentTBR;
    private bool takeMaxTbr = false; // To determine whether to take the max or min TBR values
    // Public variables to store the final average TBR values
    public float averageRelaxationTbr;
    public float averageConcentrationTbr;

    void Start()
    {
        // Ensure the buttons are assigned and listen for the click
        if (startRelaxationButton != null)
        {
            startRelaxationButton.onClick.AddListener(StartRelaxationCalibration);
        }

        if (startConcentrationButton != null)
        {
            startConcentrationButton.onClick.AddListener(StartConcentrationCalibration);
        }

        if (startGameButton != null)
        {
            startGameButton.onClick.AddListener(GameStart);
        }
        if (gameInstructionsButton != null)
        {
            gameInstructionsButton.onClick.AddListener(ToggleInstructions);
        }
        relaxationTbrText.gameObject.SetActive(true); // Show relaxation instruction
        concentrationTbrText.gameObject.SetActive(false); // Hide concentration text initially
        startConcentrationButton.gameObject.SetActive(false); // Hide concentration button
        startGameButton.gameObject.SetActive(false); // Hide start game button
        gameInstructionsButton.gameObject.SetActive(false);
        neurofeedbackGame.gameObject.SetActive(false); // Hide the dolphin game during calibration
        instructionsPanel.SetActive(false); // Ensure instructions panel is hidden initially
    }

    void ToggleInstructions()
    {
        if (instructionsPanel != null)
        {
            instructionsPanel.SetActive(!instructionsPanel.activeSelf); // Toggle visibility
        }
    }
    void Update()
    {
        // Handle relaxation calibration timing
        if (isRelaxationRecording)
        {
            relaxationElapsedTime = Time.unscaledTime - relaxationTimerStartTime; // Calculate the elapsed time for relaxation
            if (relaxationElapsedTime >= relaxationDuration)
            {
                StopRelaxationCalibration(); // Stop relaxation calibration when the duration is reached
            }
        }

        // Handle concentration calibration timing
        if (isConcentrationRecording)
        {
            concentrationElapsedTime = Time.unscaledTime - concentrationTimerStartTime; // Calculate the elapsed time for concentration
            if (concentrationElapsedTime >= concentrationDuration)
            {
                StopConcentrationCalibration(); // Stop concentration calibration when the duration is reached
            }
        }
    }

    // Start Relaxation Calibration
    public void StartRelaxationCalibration()
    {
        // Start calibration
        StartCalibration("Relaxation", true); // true for relaxation (max 10% values)
        startRelaxationButton.interactable = false; // Disable the button interaction
    }

    // Start Concentration Calibration
    public void StartConcentrationCalibration()
    {
        // Start calibration
        StartCalibration("Concentration", false); // false for concentration (min 10% values)
        startConcentrationButton.interactable = false; // Disable the button interaction
    }

    // Start Calibration (Relaxation or Concentration)
    void StartCalibration(string task, bool takeMaxTbrValue)
    {
        LSLManager.Instance.PushEvent($"Started {task} Calibration");
        currentTBR = tbrScript.GetAverageTbr(); // Get initial TBR value
        if (currentTBR != 0) // Only start if TBR is valid
        {
            // Set the appropriate start time and recording flag based on the task
            if (task == "Relaxation")
            {
                relaxationTimerStartTime = Time.unscaledTime; // Store the start time for relaxation
                isRelaxationRecording = true; // Start relaxation recording
                StartCoroutine(RecordTBR()); // Start the TBR recording coroutine
            }
            else if (task == "Concentration")
            {
                int randomNumber = Random.Range(300, 501); // Generate random number between 300 and 500 for serial 7s
                concentrationTbrText.text = $"Random Number: {randomNumber}"; // Display the random number in the instructions

                concentrationTimerStartTime = Time.unscaledTime; // Store the start time for concentration
                isConcentrationRecording = true; // Start concentration recording
                StartCoroutine(RecordTBR()); // Start the TBR recording coroutine
            }

            takeMaxTbr = takeMaxTbrValue; // Save whether it's the concentration calibration task or not
        }
        else
        {
            Debug.LogWarning("TBR is zero, cannot start calibration.");
        }
    }

    // Stop the relaxation calibration process and calculate min TBR values
    void StopRelaxationCalibration()
    {
        // Push a more specific event message for Relaxation
        LSLManager.Instance.PushEvent($"Stopped Relaxation Calibration");

        isRelaxationRecording = false; // Stop relaxation recording
        //Debug.Log("Relaxation calibration finished");

        CalculateMaxTbr(); // Calculate min TBR for relaxation

        startConcentrationButton.gameObject.SetActive(true); // Show concentration button
        concentrationTbrText.gameObject.SetActive(true); // Show concentration instruction
    }

    // Stop the concentration calibration process and calculate max TBR values
    void StopConcentrationCalibration()
    {
        // Push a more specific event message for Concentration
        LSLManager.Instance.PushEvent($"Stopped Concentration Calibration");

        isConcentrationRecording = false; // Stop concentration recording
        //Debug.Log("Concentration calibration finished");

        CalculateMinTbr(); // Calculate max TBR for concentration

        startGameButton.gameObject.SetActive(true); // Show start game button
        gameInstructionsButton.gameObject.SetActive(true);
    }

    // Coroutine for recording TBR data
    IEnumerator RecordTBR()
    {
        while (isRelaxationRecording || isConcentrationRecording) // Keep recording while either calibration is running
        {
            currentTBR = tbrScript.GetAverageTbr(); // Get the latest TBR value
            if (currentTBR != 0) // Only record if TBR is valid
            {
                if (isRelaxationRecording)
                {
                    relaxationTbrValues.Add(currentTBR); // Store the TBR value for relaxation
                }
                if (isConcentrationRecording)
                {
                    concentrationTbrValues.Add(currentTBR); // Store the TBR value for concentration
                }
            }
            yield return new WaitForSeconds(WaitSeconds); // Wait before recording next value
        }
    }

    // Calculate and display the min TBR for relaxation
    void CalculateMaxTbr()
    {
        if (relaxationTbrValues.Count == 0) return; // No data to process

        // Sort values to find the highest 10%
        relaxationTbrValues.Sort();
        int count = relaxationTbrValues.Count;
        int threshold = Mathf.CeilToInt(count * 0.1f); // Find the threshold for 10%

        List<float> selectedValues = relaxationTbrValues.GetRange(count - threshold, threshold); // Get the highest 10%

        // Calculate the average of the selected values
        float averageTBR = 0f;
        foreach (var value in selectedValues)
        {
            averageTBR += value;
        }
        averageTBR /= selectedValues.Count;
        averageRelaxationTbr = averageTBR; // Store in public variable
        // Display the average in the relaxation text box
        relaxationTbrText.text = $"Average Max TBR (Relaxation): {averageTBR:F2}";
        //relaxationTbrText.gameObject.SetActive(true); // Show relaxation result

        Debug.Log($"Relaxation Calibration Complete: Average TBR = {averageTBR:F2}");
    }

    // Calculate and display the max TBR for concentration
    void CalculateMinTbr()
    {
        if (concentrationTbrValues.Count == 0) return; // No data to process

        // Sort values to find the lowest 10%
        concentrationTbrValues.Sort();
        int count = concentrationTbrValues.Count;
        int threshold = Mathf.CeilToInt(count * 0.1f); // Find the threshold for 10%

        List<float> selectedValues = concentrationTbrValues.GetRange(0, threshold); // Get the lowest 10%

        // Calculate the average of the selected values
        float averageTBR = 0f;
        foreach (var value in selectedValues)
        {
            averageTBR += value;
        }
        averageTBR /= selectedValues.Count;
        averageConcentrationTbr = averageTBR; // Store in public variable
        // Display the average in the concentration text box
        concentrationTbrText.text = $"Average Min TBR (Concentration): {averageTBR:F2}";
        concentrationTbrText.gameObject.SetActive(true); // Show concentration result

        Debug.Log($"Concentration Calibration Complete: Average TBR = {averageTBR:F2}");
    }

    // Start the main game
    public void GameStart()
    {
        LSLManager.Instance.PushEvent("Started Neurofeedback Game");
        neurofeedbackGame.gameObject.SetActive(true); // Activate the game
        //startGameButton.gameObject.SetActive(false); // Hide the start game button
        gameObject.SetActive(false); // Deactivate the GameObject
    }
}

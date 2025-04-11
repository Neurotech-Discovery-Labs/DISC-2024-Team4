using UnityEngine;
using UnityEngine.UI;  // For UI elements
using TMPro;           // If using TextMeshPro

public class EndGameManager : MonoBehaviour
{
    public float gameDurationMinutes = 10f; // Set in minutes from the Inspector
    public GameObject endScreenPanel;  // Reference to the panel
    public TextMeshProUGUI scoreTMP;   // TextMeshPro (if used)
    
    [SerializeField] private float timer = 0f;
    private bool gameEnded = false;
    public RoachSpawner roachSpawner; //reference to fishspawner script

    void Start()
    {
        timer = 0f; // Reset timer at start
    }

    void Update() //JS feb 15 update
    {
        // Check if spawning has started before starting the timer
        if (roachSpawner != null && roachSpawner.GetIsSpawning() && !gameEnded)
        {
            timer += Time.deltaTime;

            if (timer >= gameDurationMinutes * 60f) // Convert minutes to seconds
            {
                EndGame();
                Debug.Log("Game over");
            }
        }
    }
    /*
    void Update() //old working code
    {
        if (!gameEnded)
        {
            timer += Time.deltaTime;

            if (timer >= gameDurationMinutes *60f) //convert minutes to seconds
            {
                EndGame();
                Debug.Log("game over");
            }
        }
    }
    */
    public void EndGame()
    {
        
        Debug.Log("called EndGame()");
        gameEnded = true;
        endScreenPanel.SetActive(true); // Show the end screen
        Canvas.ForceUpdateCanvases(); // Ensure UI updates
        Time.timeScale = 0f;            // Pause the game

        // Get the final score (Replace 'ScoreManager' with your actual script)
        int finalScore = ScoreTracker.Instance.GetScore(); 
        LSLManager.Instance.PushEvent("Ended Game, score: " + finalScore);
        // Update the UI
        if (scoreTMP != null) scoreTMP.text = "Game Over!\nFinal Score: " + finalScore;
    }
    /*
    // Restart function (attach to a button)
    public void RestartGame()
    {
        Time.timeScale = 1f; // Resume time
        UnityEngine.SceneManagement.SceneManager.LoadScene(0); // Reload scene
    }
    */
}

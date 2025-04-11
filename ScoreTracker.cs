using UnityEngine;
using TMPro; // Required for TextMeshPro

public class ScoreTracker : MonoBehaviour
{
    public static ScoreTracker Instance; // Singleton for global access
    public TextMeshProUGUI scoreText; // Reference to the Text UI element
    private int score = 0; // Player's score

    private void Awake()
    {
        // Ensure there's only one instance of the GameManager
        if (Instance == null)
        {
            Instance = this;
        }
        else
        {
            Destroy(gameObject);
        }
    }
    void Update()
    {
        LSLManager.Instance.PushEvent("Score: " + score);
    }
    // Method to increment and update the score
    public void AddScore(int value)
    {
        score += value;
        UpdateScoreText();
    }

    private void UpdateScoreText()
    {
        if (scoreText != null)
        {
            scoreText.text = "Score: " + score;
        }
    }
    //to update the score for the zigzag freuqency in fishcontroller
    public int GetScore()
    {
        return score;
    }
}

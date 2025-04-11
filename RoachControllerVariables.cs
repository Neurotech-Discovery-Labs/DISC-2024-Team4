using UnityEngine;

public class RoachControllerVariables : MonoBehaviour
{
    [Header("Fish Movement")]
    public float xEndPoint = -30f; //where fish is destroyed
    public float speed = 3f;
    public float zigzagAmplitude = 1f;
    public int pointsPerLevel = 20;
    public int pointsPerSpeed = 50;
    public float speedIncrement = 0.4f;
    public float levelZigZagIncrement = 0.3f;
    public float zigzagFrequency;
    public float yJiggleFactor = 0.5f; //jiggle up and down y axis for noise for fish

    [Header("Scoring")]
    public int nBackPoints = 10;
    public int badFishPenalty = -10;
}

using UnityEngine;

public class PenaltyRoachSpawner : MonoBehaviour
{
    public GameObject penaltyRoachPrefab;
    private RoachSpawner roachSpawner; // Reference to the existing RoachSpawner script
    public float penaltySpawnInterval = 0.5f;
    public float pointsPerPenaltySpawnIncrease = 50f;

    private float spawnTimer = 0f;

    private void Start()
    {
        roachSpawner = Object.FindFirstObjectByType<RoachSpawner>(); // Find the existing RoachSpawner in the scene
        if (roachSpawner == null)
        {
            Debug.LogError("RoachSpawner not found in the scene! RoachPenaltySpawner will not work.");
        }
    }

    private float GetSpeed()
    {
        int score = ScoreTracker.Instance.GetScore();
        float penaltySpawnDecrease = score / pointsPerPenaltySpawnIncrease;
        float newPenaltySpawnInterval = penaltySpawnInterval - penaltySpawnDecrease;
        return newPenaltySpawnInterval;
    }

    private void Update()
    {
        if (roachSpawner == null || !roachSpawner.GetIsSpawning()) return; // Only spawn if RoachSpawner is active

        spawnTimer += Time.deltaTime;

        if (spawnTimer >= penaltySpawnInterval) // Fixed spawn interval (since we ignore spawnInterval)
        {
            spawnTimer = 0f;

            if (Random.Range(0, 6) == 0) // 1 in 6 chance to spawn
            {
                SpawnRoachPenaltyFish();
            }
        }
    }
    private void SpawnRoachPenaltyFish()
    {
        float randomY = Random.Range(roachSpawner.minYspawnPoint, roachSpawner.maxYspawnPoint);
        Vector3 spawnPosition = new Vector3(roachSpawner.xSpawnPoint, randomY, 0f);
        Quaternion spawnRotation = Quaternion.Euler(0f, 270f, 0f);

        if (penaltyRoachPrefab != null)
        {
            Instantiate(penaltyRoachPrefab, spawnPosition, spawnRotation);
        }
        else
        {
            Debug.LogWarning("RoachPenaltyFish prefab is not assigned!");
        }
    }
}

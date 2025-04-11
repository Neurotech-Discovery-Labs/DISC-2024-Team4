using UnityEngine;

public class ArrowDolphinControll : MonoBehaviour
{
    public float moveSpeed = 5f;
    private Animator animator;
    private bool isEating = false;  // Flag to prevent repeated animation triggers
    private Collider currentEatTrigger = null;  // Track the current EatTrigger

    private void Start()
    {
        animator = GetComponent<Animator>(); // Get animator component   
    }

    private void Update()
    {
        float moveInput = Input.GetAxis("Vertical"); // W/S or arrow keys
        transform.Translate(Vector3.up * moveInput * moveSpeed * Time.deltaTime);
        LSLManager.Instance.PushEvent("dolphin y-position: " + transform.position.y);
    }

    private void OnTriggerEnter(Collider other)
    {
        // Check if the collider is the "EatTrigger" and ensure it's not the "Fish" collider
        if (other.CompareTag("EatTrigger") && !other.CompareTag("Fish") && !isEating)
        {
            currentEatTrigger = other;  // Track which EatTrigger the dolphin collided with
            animator.SetTrigger("Eat");  // Play Eat animation
            isEating = true;  // Set flag to prevent repeated triggers
        }
    }

    private void OnTriggerExit(Collider other)
    {
        // Check if the dolphin is exiting the specific "EatTrigger" collider
        if (other == currentEatTrigger)
        {
            isEating = false;  // Reset the flag when exiting the "EatTrigger"
            currentEatTrigger = null;  // Reset the reference to the current EatTrigger
        }
    }
}

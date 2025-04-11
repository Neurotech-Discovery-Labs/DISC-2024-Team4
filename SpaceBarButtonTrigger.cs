using UnityEngine;
using UnityEngine.UI;

public class MultiButtonTrigger : MonoBehaviour
{
    public Button startRelaxButton; // Reference to the first button
    public Button startConcentrationButton; // Reference to the second button
    public Button startGameButton; // Reference to the third button
    public Button gameInstructionsButton;

    void Update()
    {
        // Check if the "1" key is pressed and trigger startRelaxButton
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            startRelaxButton.onClick.Invoke();
        }

        // Check if the "2" key is pressed and trigger startConcentrationButton
        if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            startConcentrationButton.onClick.Invoke();
        }

        // Check if the "0" key is pressed and trigger startGameButton
        if (Input.GetKeyDown(KeyCode.Alpha0))
        {
            startGameButton.onClick.Invoke();
        }

                // Check if the "3" key is pressed and trigger startGameButton
        if (Input.GetKeyDown(KeyCode.Alpha3))
        {
            gameInstructionsButton.onClick.Invoke();
        }
    }
}

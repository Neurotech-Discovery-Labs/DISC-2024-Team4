/*
using UnityEngine;
using UnityEngine.InputSystem;

public class DolphinController : MonoBehaviour
{
    public float moveSpeed = 5f; // Speed at which the dolphin moves
    public InputActionProperty trackpadUp; // Action for trackpad up click
    public InputActionProperty trackpadDown; // Action for trackpad down click

    private void OnEnable()
    {
        // Enable both actions
        trackpadUp.action.Enable();
        trackpadDown.action.Enable();
    }

    private void OnDisable()
    {
        // Disable both actions
        trackpadUp.action.Disable();
        trackpadDown.action.Disable();
    }

    private void Update()
    {
        // Move up if Trackpad Up is clicked
        if (trackpadUp.action.WasPressedThisFrame())
        {
            transform.Translate(Vector3.up * moveSpeed * Time.deltaTime);
            Debug.Log("Trackpad Up Clicked - Moving Up");
        }

        // Move down if Trackpad Down is clicked
        if (trackpadDown.action.WasPressedThisFrame())
        {
            transform.Translate(Vector3.down * moveSpeed * Time.deltaTime);
            Debug.Log("Trackpad Down Clicked - Moving Down");
        }
    }

    /*
    public InputActionReference moveAction; // Reference to the Vive trackpad input action

    private void OnEnable()
    {
        // Ensure the moveAction is enabled when the script is active
        if (moveAction != null)
        {
            moveAction.action.Enable();
        }
    }

    private void OnDisable()
    {
        // Disable the moveAction when the script is no longer active
        if (moveAction != null)
        {
            moveAction.action.Disable();
        }
    }

    private void Update()
    {
        // Check if the moveAction is valid and enabled
        if (moveAction != null && moveAction.action.enabled)
        {
            // Read the trackpad input as a Vector2 (x and y values)
            Vector2 moveInput = moveAction.action.ReadValue<Vector2>();
            
            // Debug log to verify the input
            Debug.Log("Trackpad Input: " + moveInput);
            
            // Move the dolphin up or down based on the y-value of the trackpad
            transform.Translate(Vector3.up * moveInput.y * moveSpeed * Time.deltaTime);
        }
    }
    
}



/* //AF: Trying to get Vive Controller instead of keys 

using UnityEngine;

public class DolphinController : MonoBehaviour
{
    public float moveSpeed = 5f;

    private void Update()
    {
        float moveInput = Input.GetAxis("Vertical"); // W/S or arrow keys
        transform.Translate(Vector3.up * moveInput * moveSpeed * Time.deltaTime);
        LSLManager.Instance.PushEvent("dolphin y-position: " + transform.position.y);
    }
}
*/ // AF trying to get Vive Controls working Version 2 
/*
using UnityEngine;
using UnityEngine.InputSystem;

public class DolphinController : MonoBehaviour
{
    public float moveSpeed = 5f; // Speed of movement

    public InputActionReference moveUpActionRef; // Reference to the MoveUp action
    public InputActionReference moveDownActionRef; // Reference to the MoveDown action

    private void OnEnable()
    {
        // Enable the actions
        moveUpActionRef.action.Enable();
        moveDownActionRef.action.Enable();
    }

    private void OnDisable()
    {
        // Disable the actions when the object is disabled
        moveUpActionRef.action.Disable();
        moveDownActionRef.action.Disable();
    }

    private void Update()
    {
        // Check for trackpad up click
        if (moveUpActionRef.action.triggered)
        {
            // Move the dolphin up
            transform.Translate(Vector3.up * moveSpeed * Time.deltaTime, Space.World);
            Debug.Log("Moving Up");
        }

        // Check for trackpad down click
        if (moveDownActionRef.action.triggered)
        {
            // Move the dolphin down
            transform.Translate(Vector3.down * moveSpeed * Time.deltaTime, Space.World);
            Debug.Log("Moving Down");
        }

        // Send the updated position to LSL
        LSLManager.Instance.PushEvent("dolphin y-position: " + transform.position.y);
    }
}
*/
using UnityEngine;
using UnityEngine.InputSystem;

public class DolphinController : MonoBehaviour
{
    public float moveSpeed = 5f; // Speed of movement

    public InputActionReference moveUpActionRef; // Reference to the MoveUp action
    public InputActionReference moveDownActionRef; // Reference to the MoveDown action

    private bool isMovingUp = false;
    private bool isMovingDown = false;

    private void OnEnable()
    {
        // Enable the actions if they are assigned
        if (moveUpActionRef != null)
        {
            moveUpActionRef.action.Enable();
            moveUpActionRef.action.performed += OnMoveUpPerformed;
            moveUpActionRef.action.canceled += OnMoveUpCanceled;
            Debug.Log("MoveUp Action Enabled");
        }
        else
        {
            Debug.LogError("MoveUp Action Reference is not assigned!");
        }

        if (moveDownActionRef != null)
        {
            moveDownActionRef.action.Enable();
            moveDownActionRef.action.performed += OnMoveDownPerformed;
            moveDownActionRef.action.canceled += OnMoveDownCanceled;
            Debug.Log("MoveDown Action Enabled");
        }
        else
        {
            Debug.LogError("MoveDown Action Reference is not assigned!");
        }
    }

    private void OnDisable()
    {
        // Disable the actions if they are assigned
        if (moveUpActionRef != null)
        {
            moveUpActionRef.action.performed -= OnMoveUpPerformed;
            moveUpActionRef.action.canceled -= OnMoveUpCanceled;
            moveUpActionRef.action.Disable();
            Debug.Log("MoveUp Action Disabled");
        }

        if (moveDownActionRef != null)
        {
            moveDownActionRef.action.performed -= OnMoveDownPerformed;
            moveDownActionRef.action.canceled -= OnMoveDownCanceled;
            moveDownActionRef.action.Disable();
            Debug.Log("MoveDown Action Disabled");
        }
    }

    private void Update()
    {
        // Move the dolphin up if the up trigger is held
        if (isMovingUp)
        {
            transform.Translate(Vector3.up * moveSpeed * Time.deltaTime, Space.World);
            Debug.Log("Moving Up");
        }

        // Move the dolphin down if the down trigger is held
        if (isMovingDown)
        {
            transform.Translate(Vector3.down * moveSpeed * Time.deltaTime, Space.World);
            Debug.Log("Moving Down");
        }

        // Send the updated position to LSL
        if (LSLManager.Instance != null)
        {
            LSLManager.Instance.PushEvent("dolphin y-position: " + transform.position.y);
        }
        else
        {
            Debug.LogError("LSLManager instance is not assigned!");
        }
    }

    private void OnMoveUpPerformed(InputAction.CallbackContext context)
    {
        // Start moving up when the up trigger is pressed
        isMovingUp = true;
        isMovingDown = false; // Stop moving down
        Debug.Log("MoveUp Trigger Pressed");
    }

    private void OnMoveUpCanceled(InputAction.CallbackContext context)
    {
        // Stop moving up when the up trigger is released
        isMovingUp = false;
        Debug.Log("MoveUp Trigger Released");
    }

    private void OnMoveDownPerformed(InputAction.CallbackContext context)
    {
        // Start moving down when the down trigger is pressed
        isMovingDown = true;
        isMovingUp = false; // Stop moving up
        Debug.Log("MoveDown Trigger Pressed");
    }

    private void OnMoveDownCanceled(InputAction.CallbackContext context)
    {
        // Stop moving down when the down trigger is released
        isMovingDown = false;
        Debug.Log("MoveDown Trigger Released");
    }
}

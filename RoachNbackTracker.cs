using System.Collections.Generic;
using UnityEngine;

public class RoachNbackTracker : MonoBehaviour
{
    public static RoachNbackTracker Instance; //singleton for global access
    private List<string> eatenFishColors = new List<string>(); //list to track eaten fish colours
    public int n = 2; //default n-back value

    private void Awake()
    {
        //ensure only one isntasnce of N-back tracker
        if(Instance == null)
        {
            Instance = this;
        }
        else
        {
            Destroy(gameObject);
        }
    }
    public void AddColor(string colorName)
    {
        eatenFishColors.Add(colorName);
        
        // Ensure the list size doesn't exceed too long
        if (eatenFishColors.Count > n)
        {
            eatenFishColors.RemoveAt(0);  // Remove the oldest material
        }
        
        Debug.Log("Caught Fish Colors: " + string.Join(", ", eatenFishColors));
    }

    //check if current prefab is the same as prefab from n steps ago
    public bool CheckNback(string currentColor)
    {
        if(eatenFishColors.Count >= n && eatenFishColors[eatenFishColors.Count - n] == currentColor)
        {
            return true; //match with n-back colour
        }
        return false; // no match
    }
}

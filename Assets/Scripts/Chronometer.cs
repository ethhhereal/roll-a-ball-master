﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class Chronometer : MonoBehaviour
{

    public Text time;
    float chronometer;
    // Start is called before the first frame update
    void Start()
    {
    time.text = "hola";
    }

    // Update is called once per frame
    void Update()
    {
         chronometer += Time.deltaTime;
         time.text = "" + Mathf.Floor(chronometer);
    }
}

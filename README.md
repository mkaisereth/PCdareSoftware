# PCdareSoftware

CC BY-NC-SA 4.0 License  
Attribution-NonCommercial-ShareAlike 4.0 International  
Copyright (c) 2024 Mirko Kaiser  

<!-- GETTING STARTED -->
## Getting Started

1. Clone repository incl. data  
    a) Balgrist: sample data for 3 patients  
2. Have MATLAB 2021b installed  
3. Run StartPCdareRegisterApp.m in MATLAB  
4. To use your own data and switch into drawing mode adjust the following lines in StartPCdareRegisterApp.m  
    a) Line 14: basePath = "PathToYourData";  
    b) Line 46: loadLastDcmFile = false;  
    c) Line 47: loadLastPcFile = false;  
    d) Line 49: drawOnly = true;  

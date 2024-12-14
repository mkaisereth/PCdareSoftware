import os
import glob
import numpy as np
import matplotlib.pyplot as plt
import time

#basePath to use for data
dataSetName = "AsymMapPaperData"
basePath = "AsymMapPaperData"
subfolders = [ f.path for f in os.scandir(basePath) if f.is_dir() ]
subfolders.sort()
print("NumOfSubfolder: " + str(len(subfolders)))

# write used order
filepath = basePath+'/npyOrder.txt'
output = open(filepath,'w')

# width and height of depth maps
dMapWidth = 480 #640
dMapHeight = 480 #480

# check number of files
filesCounter=0;
for f in subfolders:
    csvFileNames = glob.glob(f + "/*nanDepthMap.csv")
    csvFileNames.sort();
    for cfn in csvFileNames:
        filesCounter=filesCounter+1
# convert all csv depth maps to npy
data = np.empty((filesCounter, dMapHeight, dMapWidth, 1), dtype='float32')
counter=0;
for f in subfolders:
    csvFileNames = glob.glob(f + "/*nanDepthMap.csv")
    csvFileNames.sort();
    for cfn in csvFileNames:
        if counter <= 3:
            print(cfn)
        data[counter,:,:,0] = np.loadtxt(cfn, dtype='float32', delimiter=',')
        counter=counter+1
        output.write(cfn)
        output.write("\n")

output.close()

# replace all nan
for i in range(len(data)):
    #print("image " + str(i) + " ...")
    for j in range(len(data[i])):
        for k in range(len(data[i,j])):
            if np.isnan(data[i,j,k]):
                data[i,j,k, 0] = 0
            #else:
                #print(str(data[i,j,k,0]))
                

plt.imshow(data[0,:,:,0], interpolation='nearest')
plt.show()

np.save(basePath+'/x_train_'+dataSetName+'.npy', data)

# convert all ESL csv depth maps to npy
data = np.empty((filesCounter, dMapHeight, dMapWidth, 1), dtype='float32')
counter=0;
for f in subfolders:
    #print(f)
    csvFileNames = glob.glob(f + "/*nanEslDepthMap.csv")
    csvFileNames.sort();
    for cfn in csvFileNames:
        if counter <= 3:
            print(cfn)
        data[counter,:,:,0] = np.loadtxt(cfn, dtype='float32', delimiter=',')
        counter=counter+1

# replace all nan
for i in range(len(data)):
    #print("image " + str(i) + " ...")
    for j in range(len(data[i])):
        for k in range(len(data[i,j])):
            if np.isnan(data[i,j,k]):
                data[i,j,k, 0] = 0

plt.imshow(data[0,:,:,0], interpolation='nearest')
plt.show()

np.save(basePath+'/z_train_'+dataSetName+'ESL.npy', data)
print("all done.")
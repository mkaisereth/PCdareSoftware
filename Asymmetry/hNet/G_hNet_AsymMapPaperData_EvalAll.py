from PIL import Image
import numpy as np
import os
import math
import matplotlib.pyplot as plt
import datetime
from tensorflow.keras.layers import *
from tensorflow.keras.models import *
from tensorflow.keras.optimizers import *
from tensorflow.keras.callbacks import *
from tensorflow.keras import backend as K

from tensorflow import keras
import tensorflow as tf

# level of output details
verboseLevel = 1

# width and height of depth maps
dMapWidth = 480 #640
dMapHeight = 480 #480

# dirPath to data (relative to current dir)
datasetName = 'AsymMapPaperDataAll'
basePath = 'AsymMapPaperData_All'
datasetName = 'AsymMapPaperData'
basePath = 'AsymMapPaperData'

testPathX = '/' + basePath + '/x_train_'+datasetName+'.npy'

doEvalFor = 'ESL'
#doEvalFor = 'ISL'

# only use a subset for training (if all, use full number)
useSubSet = False
subSetStartNr = 400 #0 python is weird 0:400 gives 400 elements (from 0 to 399)
subSetEndNr = 878 #400

useBatches = True
batchSize = 6

# rmse calculation
def rmse(y_true, y_predict):
    return K.sqrt(K.mean(K.square((y_true/4.4)-(y_predict/4.4))))

## evaluate the learned model
def evaluation(dir, X_test, info):
    ### This is an example of write the point clouud .txt files from 6 different outputs of hNet, last two outputs are reliable.
    model = load_model(dir + '/model_'+info+'.h5', custom_objects={'rmse' : rmse})
    Z_1= model.predict(X_test, batch_size =1, verbose =verboseLevel)

    print("Z_1 " + str(len(Z_1)))
    print(Z_1[0].shape)
    print("Z_1[0] " + str(len(Z_1[0])))
    print("Z_1[0][0] " + str(len(Z_1[0][0])))

    # read order to save with original identifier
    filepath = basePath+'/npyOrder.txt'
    file1 = open(filepath, "r")
    orderLines = file1.readlines()
    file1.close()
    orderLinesOffset = 0
    if useSubSet:
        orderLinesOffset = subSetStartNr

    # use last metric (according to paper 5 and 6 are reliable)
    mi = 5
    for k in range(len(Z_1[mi])):
        print(orderLines[orderLinesOffset+k].replace("\n", ""))
        Z = np.reshape(Z_1[mi][k], (dMapHeight, dMapWidth))
        filepath = dir+'/'+ doEvalFor + '_' + orderLines[orderLinesOffset+k].replace(basePath+"/", "").replace("/", "_").replace("\\", "_").replace("\n", "").replace("_nanDepthMap.csv", "") +'_5.txt' 
        output = open(filepath,'w')

        for i in range(dMapHeight):
            for j in range(dMapWidth):
                output.write(str(i))
                output.write(" ")
                output.write(str(dMapWidth-1-j))
                output.write(" ")
                output.write('%.6f'%(Z[i,j]))
                output.write("\n")
        output.close()

    ### This is an example of write the 3D .txt file from UNet.
    #model = load_model(dir + '/model_UNet_fringe.h5', custom_objects={'rmse' : rmse})
    #Z_1= model.predict(X_test[1:2], batch_size =1, verbose =verboseLevel)
    #Z = np.reshape(Z_1, (dMapHeight, dMapWidth))
    #filepath = dir+'/Unet_example.txt' 
    #output = open(filepath,'w')

    #for i in range(dMapWidth):
    #    for j in range(dMapHeight):
    #        if (Z[j,i]>50):
    #            output.write(str(i))
    #            output.write(" ")
    #            output.write(str(dMapHeight-1-j))
    #            output.write(" ")
    #            output.write('%.6f'%(Z[j,i]))
    #            output.write("\n")
    #output.close()

def evaluation2(dir, X_test, model, orderLines, orderLinesOffset):
    ### This is an example of write the point clouud .txt files from 6 different outputs of hNet, last two outputs are reliable.
    Z_1= model.predict(X_test, batch_size =1, verbose =verboseLevel)    
    # use last metric (according to paper 5 and 6 are reliable)
    mi = 5
    for k in range(len(Z_1[mi])):
        #print(orderLines[orderLinesOffset+k].replace("\n", ""))
        Z = np.reshape(Z_1[mi][k], (dMapHeight, dMapWidth))
        filepath = dir+'/'+ doEvalFor + '_' + orderLines[orderLinesOffset+k].replace(basePath+"/", "").replace("/", "_").replace("\\", "_").replace("\n", "").replace("_nanDepthMap.csv", "") +'_5.txt' 
        output = open(filepath,'w')

        for i in range(dMapHeight):
            for j in range(dMapWidth):
                output.write(str(i))
                output.write(" ")
                output.write(str(dMapWidth-1-j))
                output.write(" ")
                output.write('%.6f'%(Z[i,j]))
                output.write("\n")
        output.close()

if __name__ == '__main__':

    print(datetime.datetime.now())
    
    dir = os.path.abspath(os.curdir)
    
    if useBatches == False:
        # test data input (X)
        X_test = np.load(dir + testPathX)
        if useSubSet:
            X_test = X_test[subSetStartNr:subSetEndNr,:,:,:]
        print(type(X_test))
        print(X_test.size)
        print(X_test.shape)

        outputDir = dir + '/Output_'+datasetName
        if not os.path.exists(outputDir):
            os.mkdir(outputDir)

        evaluation(outputDir, X_test, 'hNet'+doEvalFor)
    else:
        bi=0
        outputDir = dir + '/Output_'+datasetName
        if not os.path.exists(outputDir):
            os.mkdir(outputDir)
        model = load_model(outputDir + '/model_'+'hNet'+doEvalFor+'.h5', custom_objects={'rmse' : rmse})
        # read order to save with original identifier
        filepath = basePath+'/npyOrder.txt'
        file1 = open(filepath, "r")
        orderLines = file1.readlines()
        file1.close()
        while True:
            testPathX = '/' + basePath + '/x_train_'+datasetName+'_'+str(bi)+'_'+str(batchSize)+'.npy'
            # test data input (X)
            X_test = np.load(dir + testPathX)
            #print(type(X_test))
            #print(X_test.size)
            
            orderLinesOffset = bi
            evaluation2(outputDir, X_test, model, orderLines, orderLinesOffset)
            bi=bi+batchSize

    print(datetime.datetime.now())

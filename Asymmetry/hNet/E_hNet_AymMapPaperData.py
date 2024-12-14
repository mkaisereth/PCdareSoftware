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
# initial learning rate
initialLearningRate = 0.0001
# number of epochs of training
numOfEpochs = 3#200
# batch size to use for training
batchSize = 6
stepsPerEpoch = 84#456
# yMax for error figure (TODO, use real)
errorYMax = 1

# width and height of depth maps
dMapWidth = 480 #640
dMapHeight = 480 #480

# dirPath to data (relative to current dir)
datasetName = 'AsymMapPaperData'
trainPathBase = '/AsymMapPaperData'
trainPathX = trainPathBase+'/x_train_AsymMapPaperData.npy'
trainPathZESL = trainPathBase+'/z_train_AsymMapPaperDataESL.npy'
testPathX = '/AsymMapPaperData/x_train_AsymMapPaperData.npy'
testPathZESL = '/AsymMapPaperData/z_train_AsymMapPaperDataESL.npy'

# only use a subset for training (if all, use full number)
useSubSet = False
subSetNr = 300

# rmse calculation
def rmse(y_true, y_predict):
    return K.sqrt(K.mean(K.square((y_true/4.4)-(y_predict/4.4))))

## hNet
def hNet(height,width, channels, drop =0.2, alpha = 0.3):
	
	def third_branch(x, up_scale):
		if (up_scale>1):
			x = LeakyReLU(0.3)(Conv2D(1, 1, activation = None, padding='same', kernel_initializer = 'he_normal')(x))
			x = Conv2DTranspose(1, 2*up_scale, strides = up_scale, padding='same', activation=None, use_bias = False)(x)
		else:
			x = LeakyReLU(0.3)(Conv2D(1, 1, activation = None, padding='same', kernel_initializer = 'he_normal')(x))
		return x
	
	inputs = Input((height, width, channels))
	# First branch
	conv1 = LeakyReLU(alpha)(Conv2D(32, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(inputs))
	conv1 = LeakyReLU(alpha)(Conv2D(32, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv1))
	pool1 = MaxPooling2D(pool_size=(2, 2))(conv1)

	conv2 = LeakyReLU(alpha)(Conv2D(64, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(pool1))
	conv2 = LeakyReLU(alpha)(Conv2D(64, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv2))
	pool2 = MaxPooling2D(pool_size=(2, 2))(conv2)

	conv3 = LeakyReLU(alpha)(Conv2D(128, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(pool2))
	conv3 = LeakyReLU(alpha)(Conv2D(128, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv3))
	pool3 = MaxPooling2D(pool_size=(2, 2))(conv3)

	conv4 = LeakyReLU(alpha)(Conv2D(256, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(pool3))
	conv4 = LeakyReLU(alpha)(Conv2D(256, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv4))
	pool4 = MaxPooling2D(pool_size=(2, 2))(conv4)

	conv5 = LeakyReLU(alpha)(Conv2D(512, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(pool4))
	conv5 = LeakyReLU(alpha)(Conv2D(512, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv5))
	drop5 = Dropout(drop)(conv5)

	# Second branch
	up6 = Concatenate()([Conv2DTranspose(256, 3, strides = 2, padding='same', kernel_initializer = 'he_normal')(drop5), conv4])
	conv6 = LeakyReLU(alpha)(Conv2D(256, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(up6))
	conv6 = LeakyReLU(alpha)(Conv2D(256, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv6))

	up7 = Concatenate()([Conv2DTranspose(128, 3, strides = 2, padding='same', kernel_initializer = 'he_normal')(conv6), conv3])
	conv7 = LeakyReLU(alpha)(Conv2D(128, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(up7))
	conv7 = LeakyReLU(alpha)(Conv2D(128, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv7))

	up8 = Concatenate()([Conv2DTranspose(64, 3, strides = 2, padding='same', kernel_initializer = 'he_normal')(conv7), conv2])
	conv8 = LeakyReLU(alpha)(Conv2D(64, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(up8))
	conv8 = LeakyReLU(alpha)(Conv2D(64, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv8))

	up9 = Concatenate()([Conv2DTranspose(32, 3, strides = 2, padding='same', kernel_initializer = 'he_normal')(conv8), conv1])
	conv9 = LeakyReLU(alpha)(Conv2D(32, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(up9))
	conv9 = LeakyReLU(alpha)(Conv2D(32, 3, activation = None, padding='same', kernel_initializer = 'he_normal')(conv9))

	# Third branch
	c1 = third_branch(drop5,16)
	c2 = third_branch(conv6,8)
	c3 = third_branch(conv7,4)
	c4 = third_branch(conv8,2)
	c5 = third_branch(conv9,1)

	o1 = Conv2D(1, 1, activation = 'linear')(c1)
	o2 = Conv2D(1, 1, activation = 'linear')(c2)
	o3 = Conv2D(1, 1, activation = 'linear')(c3)
	o4 = Conv2D(1, 1, activation = 'linear')(c4)
	o5 = Conv2D(1, 1, activation = 'linear')(c5)

	fuse = Concatenate()([c1, c2, c3, c4, c5])
	fuse = Conv2D(1, 1, activation = 'linear')(fuse)

	model = Model(inputs=[inputs], outputs=[o1,o2,o3,o4,o5,fuse])
	return model

## UNet
def UNet(height, width, channels, alpha = 0.4, drop = 0.2):
    inputs = Input((height, width, channels))
    
    conv1 = LeakyReLU(alpha)(Conv2D(32, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(inputs))
    conv1 = LeakyReLU(alpha)(Conv2D(32, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv1))
    pool1 = MaxPooling2D(pool_size=(2, 2))(conv1)

    conv2 = LeakyReLU(alpha)(Conv2D(64, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(pool1))
    conv2 = LeakyReLU(alpha)(Conv2D(64, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv2))
    pool2 = MaxPooling2D(pool_size=(2, 2))(conv2)

    conv3 = LeakyReLU(alpha)(Conv2D(128, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(pool2))
    conv3 = LeakyReLU(alpha)(Conv2D(128, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv3))
    pool3 = MaxPooling2D(pool_size=(2, 2))(conv3)

    conv4 = LeakyReLU(alpha)(Conv2D(256, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(pool3))
    conv4 = LeakyReLU(alpha)(Conv2D(256, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv4))
    pool4 = MaxPooling2D(pool_size=(2, 2))(conv4)

    conv5 = LeakyReLU(alpha)(Conv2D(512, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(pool4))
    conv5 = LeakyReLU(alpha)(Conv2D(512, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv5))
    drop5 = Dropout(drop)(conv5)

    up6 = concatenate([Conv2DTranspose(256, (3, 3), strides=(2, 2), padding='same', kernel_initializer = 'he_normal')(drop5), conv4], axis=3)
    conv6 = LeakyReLU(alpha)(Conv2D(256, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(up6))
    conv6 = LeakyReLU(alpha)(Conv2D(256, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv6))

    up7 = concatenate([Conv2DTranspose(128, (3, 3), strides=(2, 2), padding='same', kernel_initializer = 'he_normal')(conv6), conv3], axis=3)
    conv7 = LeakyReLU(alpha)(Conv2D(128, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(up7))
    conv7 = LeakyReLU(alpha)(Conv2D(128, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv7))

    up8 = concatenate([Conv2DTranspose(64, (3, 3), strides=(2, 2), padding='same', kernel_initializer = 'he_normal')(conv7), conv2], axis=3)
    conv8 = LeakyReLU(alpha)(Conv2D(64, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(up8))
    conv8 = LeakyReLU(alpha)(Conv2D(64, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv8))

    up9 = concatenate([Conv2DTranspose(32, (3, 3), strides=(2, 2), padding='same', kernel_initializer = 'he_normal')(conv8), conv1], axis=3)
    conv9 = LeakyReLU(alpha)(Conv2D(32, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(up9))
    conv9 = LeakyReLU(alpha)(Conv2D(32, (3, 3), activation = None, padding='same', kernel_initializer = 'he_normal')(conv9))

    conv10 = Conv2D(1, (1, 1), activation='linear')(conv9)

    model = Model(inputs=[inputs], outputs=[conv10])
    return model

# decay function
def step_decay(epoch, lr):
    drop = 0.997 # drop rate
    epochs_drop = 100.0 # start reducing after number of epochs
    # learning rate decay
    lrate = lr*math.pow(drop, math.floor((1+epoch)/epochs_drop))
    return lrate

# custom callback for user output
class CustomCallback(keras.callbacks.Callback):
    #def on_train_begin(self, logs=None):
    #    keys = list(logs.keys())
    #    print("Starting training; got log keys: {}".format(keys))

    #def on_train_end(self, logs=None):
    #    keys = list(logs.keys())
    #    print("Stop training; got log keys: {}".format(keys))

    def on_epoch_begin(self, epoch, logs=None):
        keys = list(logs.keys())
        print("Start epoch {} of training; got log keys: {}".format(epoch, keys))

    def on_epoch_end(self, epoch, logs=None):
        keys = list(logs.keys())
        print("End epoch {} of training; got log keys: {}".format(epoch, keys))

    #def on_test_begin(self, logs=None):
    #    keys = list(logs.keys())
    #    print("Start testing; got log keys: {}".format(keys))

    #def on_test_end(self, logs=None):
    #    keys = list(logs.keys())
    #    print("Stop testing; got log keys: {}".format(keys))

    #def on_predict_begin(self, logs=None):
    #    keys = list(logs.keys())
    #    print("Start predicting; got log keys: {}".format(keys))

    #def on_predict_end(self, logs=None):
    #    keys = list(logs.keys())
    #    print("Stop predicting; got log keys: {}".format(keys))

    #def on_train_batch_begin(self, batch, logs=None):
    #    keys = list(logs.keys())
    #    print("...Training: start of batch {}; got log keys: {}".format(batch, keys))

    #def on_train_batch_end(self, batch, logs=None):
    #    keys = list(logs.keys())
    #    print("...Training: end of batch {}; got log keys: {}".format(batch, keys))

    #def on_test_batch_begin(self, batch, logs=None):
    #    keys = list(logs.keys())
    #    print("...Evaluating: start of batch {}; got log keys: {}".format(batch, keys))

    #def on_test_batch_end(self, batch, logs=None):
    #    keys = list(logs.keys())
    #    print("...Evaluating: end of batch {}; got log keys: {}".format(batch, keys))

    #def on_predict_batch_begin(self, batch, logs=None):
    #    keys = list(logs.keys())
    #    print("...Predicting: start of batch {}; got log keys: {}".format(batch, keys))

    #def on_predict_batch_end(self, batch, logs=None):
    #    keys = list(logs.keys())
    #    print("...Predicting: end of batch {}; got log keys: {}".format(batch, keys))

## train the model with hNet
def train_model_hNet(model, dir, x_train, y_train, info):
    lrate = LearningRateScheduler(step_decay, verbose=verboseLevel)
    
    #For NNet only, multiple outputs
    y_train = [y_train,y_train,y_train,y_train,y_train,y_train]
    model.compile(optimizer = Adam(initialLearningRate), loss = ['mse', 'mse', 'mse', 'mse', 'mse', 'mse'], metrics=[rmse])

    model_checkpoint = ModelCheckpoint( dir + '/model_' + info + '.h5', monitor='val_loss',verbose=verboseLevel, save_best_only=True)
    callbacks_list = [lrate, model_checkpoint, CustomCallback()]
    
    # Load data
    def generate_arrays_from_file():
        batch = 0
        batch_sum=0
        currentBatch = -1
        while True:
            startOfBatch = batch_sum//batchSize
            startOfBatch = startOfBatch*batchSize
            #print("\nGoing to load new pair: " + str(batch) + " from batch " + str(startOfBatch) + " total: " + str(batch_sum) + "\n")
            batch_sum=batch_sum+1
            if batch_sum>=stepsPerEpoch:
                batch_sum = 0
                
            #print('\nhuhu ' + str(batch) + ' ' + str(startOfBatch))

            #x_train_1 = x_train
            #y_train_1 = y_train
            if currentBatch != startOfBatch:
                x_train_1 = np.load(os.path.abspath(os.curdir)+ '/' + trainPathBase + '/x_train_'+datasetName+'_'+str(startOfBatch)+'_'+str(batchSize)+'.npy')
                y_train_1 = np.load(os.path.abspath(os.curdir)+ '/' + trainPathBase + '/z_train_'+datasetName+'ESL_'+str(startOfBatch)+'_'+str(batchSize)+'.npy')
                #print("\nDid load new batch: " + str(startOfBatch) + "\n")
                currentBatch = startOfBatch

            x_batch=x_train_1[batch:batch+1]
            y_batch_temp = y_train_1[batch:batch+1]
            batch=batch+1
            if batch >= len(x_train_1):
                batch = 0
            y_batch=[y_batch_temp,y_batch_temp,y_batch_temp,y_batch_temp,y_batch_temp,y_batch_temp]
            yield (x_batch, y_batch)

    history=model.fit(generate_arrays_from_file(), batch_size = batchSize, epochs = numOfEpochs, verbose=verboseLevel, shuffle  = True, callbacks = callbacks_list, steps_per_epoch = stepsPerEpoch, validation_data = generate_arrays_from_file(), validation_steps = 3)

    # plot the error progression as figures
    plt.figure()
    plt.plot(history.history['conv2d_23_rmse'])
    plt.plot(history.history['val_conv2d_23_rmse'])
    plt.axis([-10, numOfEpochs+10, 0, errorYMax])
    plt.annotate("{:.2f}".format(history.history['val_conv2d_23_rmse'][numOfEpochs-1]), xy=(numOfEpochs, history.history['val_conv2d_23_rmse'][numOfEpochs-1]), xytext = (-10, 30),  xycoords = "data", textcoords = 'offset points', arrowprops = dict(arrowstyle="->", connectionstyle="arc3"))
    plt.savefig(dir+'/' + info + '1_rmse.png')
    
    plt.figure()
    plt.plot(history.history['conv2d_24_rmse'])
    plt.plot(history.history['val_conv2d_24_rmse'])
    plt.axis([-10, numOfEpochs+10, 0, errorYMax])
    plt.annotate("{:.2f}".format(history.history['val_conv2d_24_rmse'][numOfEpochs-1]), xy=(numOfEpochs, history.history['val_conv2d_24_rmse'][numOfEpochs-1]), xytext = (-10, 30),  xycoords = "data", textcoords = 'offset points', arrowprops = dict(arrowstyle="->", connectionstyle="arc3"))
    plt.savefig(dir+'/' + info + '2_rmse.png')
    
    plt.figure()
    plt.plot(history.history['conv2d_25_rmse'])
    plt.plot(history.history['val_conv2d_25_rmse'])
    plt.axis([-10, numOfEpochs+10, 0, errorYMax])
    plt.annotate("{:.2f}".format(history.history['val_conv2d_25_rmse'][numOfEpochs-1]), xy=(numOfEpochs, history.history['val_conv2d_25_rmse'][numOfEpochs-1]), xytext = (-10, 30),  xycoords = "data", textcoords = 'offset points', arrowprops = dict(arrowstyle="->", connectionstyle="arc3"))
    plt.savefig(dir+'/' + info + '3_rmse.png')
    
    plt.figure()
    plt.plot(history.history['conv2d_26_rmse'])
    plt.plot(history.history['val_conv2d_26_rmse'])
    plt.axis([-10, numOfEpochs+10, 0, errorYMax])
    plt.annotate("{:.2f}".format(history.history['val_conv2d_26_rmse'][numOfEpochs-1]), xy=(numOfEpochs, history.history['val_conv2d_26_rmse'][numOfEpochs-1]), xytext = (-10, 30),  xycoords = "data", textcoords = 'offset points', arrowprops = dict(arrowstyle="->", connectionstyle="arc3"))
    plt.savefig(dir+'/' + info + '4_rmse.png')
    
    plt.figure()
    plt.plot(history.history['conv2d_27_rmse'])
    plt.plot(history.history['val_conv2d_27_rmse'])
    plt.axis([-10, numOfEpochs+10, 0, errorYMax])
    plt.annotate("{:.2f}".format(history.history['val_conv2d_27_rmse'][numOfEpochs-1]), xy=(numOfEpochs, history.history['val_conv2d_27_rmse'][numOfEpochs-1]), xytext = (-10, 30),  xycoords = "data", textcoords = 'offset points', arrowprops = dict(arrowstyle="->", connectionstyle="arc3"))
    plt.savefig(dir+'/' + info + '5_rmse.png')
    
    plt.figure()
    plt.plot(history.history['conv2d_28_rmse'])
    plt.plot(history.history['val_conv2d_28_rmse'])
    plt.axis([-10, numOfEpochs+10, 0, errorYMax])
    plt.annotate("{:.2f}".format(history.history['val_conv2d_28_rmse'][numOfEpochs-1]), xy=(numOfEpochs, history.history['val_conv2d_28_rmse'][numOfEpochs-1]), xytext = (-10, 30),  xycoords = "data", textcoords = 'offset points', arrowprops = dict(arrowstyle="->", connectionstyle="arc3"))
    plt.savefig(dir+'/' + info + '6_rmse.png')

## train the model with hNet
def train_model_UNet(model, dir, x_train, y_train, info):
    lrate = LearningRateScheduler(step_decay, verbose=verboseLevel)
    model.compile(optimizer = Adam(initialLearningRate), loss = ['mse'], metrics=[rmse])

    model_checkpoint = ModelCheckpoint( dir + '/model_' + info + '.h5', monitor='val_loss',verbose=verboseLevel, save_best_only=True)
    callbacks_list = [lrate, model_checkpoint]
    history=model.fit(x_train, y_train, batch_size = batchSize, epochs = numOfEpochs, verbose=verboseLevel, shuffle  = True, callbacks = callbacks_list, validation_split=0.1)

    #### plot the training rmse
    #plt.figure()
    #plt.plot(history.history['rmse'])
    #plt.plot(history.history['val_rmse'])
    #plt.axis([-10, numOfEpochs+10, 0, errorYMax])
    #plt.annotate("{:.2f}".format(history.history['val_rmse'][numOfEpochs-1]), xy=(numOfEpochs, history.history['val_rmse'][numOfEpochs-1]), xytext = (-10, 30),  xycoords = "data", textcoords = 'offset points', arrowprops = dict(arrowstyle="->", connectionstyle="arc3"))
    #plt.ylabel('RMSE')
    #plt.xlabel('Epoch')
    #plt.savefig(dir+'/' + info + '_rmse.png')

## evaluate the learned model
def evaluation(dir, X_test, Z_test, info):
    ### This is an example of write the point clouud .txt files from 6 different outputs of hNet, last two outputs are reliable.
    model = load_model(dir + '/model_'+info+'.h5', custom_objects={'rmse' : rmse})
    Z_1= model.predict(X_test[0:1], batch_size =1, verbose =verboseLevel)

    print("Z_1 " + str(len(Z_1)))

    for i in range(6):
        Z = np.reshape(Z_1[i], (dMapHeight, dMapWidth))
        filepath = dir+'/'+info+'_first_' + str(i) +'.txt' 
        output = open(filepath,'w')

        for i in range(dMapHeight):
            for j in range(dMapWidth):
                #if (Z[j,i]>50):
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


if __name__ == '__main__':

    print(datetime.datetime.now())
    
    #os.environ['CUDA_VISIBLE_DEVICES'] = '-1'
    
    #if tf.config.list_physical_devices('GPU'):
    #    physical_devices = tf.config.list_physical_devices('GPU')
    #    tf.config.experimental.set_memory_growth(physical_devices[0], enable=True)
    #    tf.config.experimental.set_virtual_device_configuration(physical_devices[0], [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=4000)])

    dir = os.path.abspath(os.curdir)
    
    # Allow memory growth for the GPU
    physical_devices = tf.config.experimental.list_physical_devices('GPU')
    print(physical_devices[0])
    #tf.config.experimental.set_memory_growth(physical_devices[0], True)
    #tf.config.experimental.set_virtual_device_configuration(physical_devices[0],[tf.config.experimental.VirtualDeviceConfiguration(memory_limit=1024)])
    
    # training data input (X)
    X_train = np.load(dir + trainPathX) # X_train_fringe = np.load(dir + '/X_train_fringe.npy')
    if useSubSet:
        X_train = X_train[0:subSetNr,:,:,:]
    print(type(X_train))
    print(X_train.size)
    print(X_train.shape)
    print(X_train.ndim)
    
    # training data output (Z)
    Z_trainESL = np.load(dir + trainPathZESL) # Z_train = np.load(dir + '/Z_train.npy')
    if useSubSet:
        Z_trainESL = Z_trainESL[0:subSetNr,:,:,:]

    # test data input (X)
    X_test = np.load(dir + testPathX)
    if useSubSet:
        X_test = X_test[0:subSetNr,:,:,:]
    print(type(X_test))
    print(X_test.size)
    print(X_test.shape)

    # test data output (Z)
    Z_testESL = np.load(dir + testPathZESL)
    if useSubSet:
        Z_testESL = Z_testESL[0:subSetNr,:,:,:]

    # show an image of first training data input
    plt.imshow(X_train[0,:,:,0], interpolation='nearest')
    plt.show()
    # show an image of first training data output
    plt.imshow(Z_trainESL[0,:,:,0], interpolation='nearest')
    plt.show()
    # save the image of first training data output as txt file
    inputDir = dir + '/Input'
    if not os.path.exists(inputDir):
        os.mkdir(inputDir)
    filepath = inputDir+'/Z_train_1.txt' 
    output = open(filepath,'w')

    for i in range(dMapHeight):
        for j in range(dMapWidth):
            output.write(str(i))
            output.write(" ")
            output.write(str(dMapWidth-1-j))
            output.write(" ")
            output.write('%.6f'%(Z_trainESL[0,i,j,0]))
            output.write("\n")
    output.close()

    outputDir = dir + '/Output'
    if not os.path.exists(outputDir):
        os.mkdir(outputDir)

    doTraining = True
    doESL = True

    # use UNet
    #model = UNet(dMapHeight, dMapWidth, 1)
    #train_model_UNet(model, outputDir, X_train, Z_train, 'UNet_fringe')

    # use hNet
    if doTraining:
        if doESL:
            model = hNet(dMapHeight, dMapWidth, 1)
            train_model_hNet(model, outputDir, X_train, Z_trainESL, 'hNetESL')
    if doESL:
        evaluation(outputDir, X_test, Z_testESL, 'hNetESL')     

    print(datetime.datetime.now())

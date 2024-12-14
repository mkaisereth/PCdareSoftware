import numpy as np
import os

dir = os.path.abspath(os.curdir)

batchSize = 6

X_train_name = 'AsymMapPaperData/x_train_AsymMapPaperData'
Z_train_name = 'AsymMapPaperData/z_train_AsymMapPaperDataESL'

X_train_fringe = np.load(dir + '/' + X_train_name + '.npy')
print(X_train_name+': ' + str(len(X_train_fringe)))
Z_train = np.load(dir + '/'+Z_train_name+'.npy')
print(Z_train_name+': ' + str(len(Z_train)))

for i in range(0, len(X_train_fringe), batchSize):
    X_train_fringe_batch = X_train_fringe[i:i+batchSize]
    np.save(X_train_name+'_' + str(i) + '_' + str(batchSize) + '.npy', X_train_fringe_batch)

    Z_train_batch = Z_train[i:i+batchSize]
    np.save(Z_train_name+'_' + str(i) + '_' + str(batchSize) + '.npy', Z_train_batch)

    #test it
    X_train_fringe_batch_test = np.load(X_train_name+'_' + str(i) + '_' + str(batchSize) + '.npy')
    print(len(X_train_fringe_batch_test))

    Z_train_batch_test = np.load(Z_train_name+'_' + str(i) + '_' + str(batchSize) + '.npy')
    print(len(Z_train_batch_test))
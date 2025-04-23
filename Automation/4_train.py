from torch.utils.data import DataLoader
from unet import UNet
from data_loading import XRayDataset
import lightning as L
import pathlib
import torch
import data_processing
import numpy as np
from lightning.pytorch.callbacks import TQDMProgressBar
from torchvision import transforms
import matplotlib.pyplot as plt
from lightning.pytorch.loggers import TensorBoardLogger
import lightning as L
import skimage as ski
import worker_seed
import argparse
from lightning.pytorch.callbacks import ModelCheckpoint
from lightning.pytorch.callbacks.early_stopping import EarlyStopping
import loss

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Python script to train UNet for spine segmentation")
    parser.add_argument("--expt_name", type=str, help="The name of the experiment.")
    parser.add_argument("--lr", type=float, default=1e-4, help="The learning rate.")
    parser.add_argument("--max_epochs", type=int, default=50, help="The number of maximum epochs.")
    parser.add_argument("--batch_size", type=int, default=8, help="The batch size.")
    parser.add_argument("--loss", type=str, default="Loss", help="The loss function.")
    parser.add_argument('--pretrained', action='store_true')
    
    data_path = pathlib.Path.cwd() / "datasample" / "cc_aug"
    labels_path = pathlib.Path.cwd() / "datasample" / "cc_aug" / "validation"
    checkpoint_path = "./checkpoints/ckp_pretrained_unet_mateusz_buda.ckpt"

    args = parser.parse_args()
    
    if args.loss == "BCE":
        loss = loss.BCE()
    else:
        loss = loss.Loss()
        
    # g = torch.Generator()
    # g.manual_seed(0)
    
    LOGS_DIR = "./tb_logs"
    EXPT_NAME = args.expt_name
    CKPT_DIR = LOGS_DIR + "/" + EXPT_NAME + "/checkpoints"

    logger = TensorBoardLogger(LOGS_DIR, name=EXPT_NAME)

    xray_dataset_training = XRayDataset(data_path,
                               data_processing.preprocess_inputs,
                               data_processing.preprocess_labels)
    xray_dataset_validation = XRayDataset(labels_path,
                               data_processing.preprocess_inputs,
                               data_processing.preprocess_labels)
    
    train_dataloader = DataLoader(xray_dataset_training,
                                  batch_size=args.batch_size,
                                  shuffle=True,
                                  num_workers=4,
                                  worker_init_fn=worker_seed.seed_worker)
                                  # generator=g,)
    val_dataloader = DataLoader(
      xray_dataset_validation, batch_size=1, shuffle=False,
      num_workers=8,
    )

    model = UNet(loss=loss, lr=args.lr)
    if args.pretrained:
      print(checkpoint_path, torch.__version__)
      state_dict = torch.load(checkpoint_path)
      print(state_dict)
      model.load_state_dict(state_dict)
      print("Loaded!")

    checkpoint_callback = ModelCheckpoint(dirpath="./checkpoints/" + EXPT_NAME + "/",
                                          save_top_k=1,
                                          monitor="dice_coeff",
                                          mode="max")

    trainer = L.Trainer(logger=logger,
                    callbacks=[TQDMProgressBar(refresh_rate=1), checkpoint_callback],
                    max_epochs=args.max_epochs,
                    log_every_n_steps=1)
    trainer.fit(model,
            train_dataloader,
            val_dataloader)
    # trainer.save_checkpoint("./checkpoints/" + EXPT_NAME + "-epochs:" + str(args.max_epochs) +  ".ckpt")
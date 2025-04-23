import torch
import torchvision
from skimage.util import img_as_ubyte
import numpy as np

from torchvision import transforms
from torchvision.transforms import v2
import torchvision.transforms.functional as TF


def call_contrast(img):
    return transforms.functional.adjust_contrast(img, contrast_factor = 2)


def preprocess_inputs(img: torch.tensor):
    transform = transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize((512, 512)),
        transforms.Lambda(call_contrast),
        transforms.Grayscale(num_output_channels=3),
        transforms.ToTensor()
    ])
    return transform(img)

def preprocess_labels(img: torch.tensor):
    transform = transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize((512, 512)),
        transforms.Grayscale(num_output_channels=1),
        transforms.ToTensor(),
        transforms.Lambda(lambda image_tensor : torch.where(image_tensor >= 0.5, 1., 0.))
    ])
    return transform(img)

def postprocess(img: torch.tensor):
    img = img.cpu().numpy()  
    img = np.squeeze(img)  
    img = np.where(img < 0.5, 0, 255)
    return img             

def postprocess_during_training(img: torch.tensor):
    img = img.squeeze()
    img = torch.where(img < 0.5, 0, 255)
    return img

def resize_to_roughy_input_size(img: torch.tensor):
    transform = transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize((1024, 512)),
        transforms.ToTensor()
    ])
    return transform(img)

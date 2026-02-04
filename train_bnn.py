import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, WeightedRandomSampler
from torchvision import datasets, transforms
import os

# Assuming your model is in model.py. If not, paste your BNN class here.
from model import PCBFaultBNN 

def train_pcb_bnn():
    # 1. Hardware Setup (RTX 5060 Support)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"🚀 Training on: {device}")

    # 2. Data Augmentation (Fixes the 693-count folder imbalance)
    transform = transforms.Compose([
        transforms.Grayscale(),
        transforms.RandomHorizontalFlip(p=0.5), # Flips images to double effective data
        transforms.RandomVerticalFlip(p=0.5),   # Flips again to quadruple it
        transforms.ToTensor(),
        transforms.Normalize((0.5,), (0.5,))
    ])

    # 3. Load Dataset
    data_path = 'processed_dataset_v16'
    if not os.path.exists(data_path):
        print(f"❌ Error: {data_path} not found!")
        return

    dataset = datasets.ImageFolder(root=data_path, transform=transform)
    
    # 4. Weighted Sampler (The Equalizer for 0-6000 vs 4-693)
    targets = torch.tensor(dataset.targets)
    class_counts = torch.tensor([(targets == t).sum() for t in range(len(dataset.classes))])
    weights = 1. / class_counts.float()
    samples_weights = torch.tensor([weights[t] for t in targets])
    
    sampler = WeightedRandomSampler(
        weights=samples_weights, 
        num_samples=len(samples_weights), 
        replacement=True
    )

    # 5. Fast DataLoader for RTX 5060
    train_loader = DataLoader(
        dataset, 
        batch_size=256, 
        sampler=sampler, 
        num_workers=4, 
        pin_memory=True
    )

    # 6. Model, Optimizer, and Loss
    model = PCBFaultBNN().to(device)
    optimizer = optim.Adam(model.parameters(), lr=0.001, weight_decay=1e-5)
    criterion = nn.CrossEntropyLoss()

    # 7. Training Loop
    epochs = 30
    print(f"📊 Dataset Stats: {class_counts.tolist()}")
    print("✨ Starting Training...")

    for epoch in range(epochs):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0

        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device)

            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item()
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

        epoch_acc = 100 * correct / total
        print(f"Epoch [{epoch+1}/{epochs}] - Loss: {running_loss/len(train_loader):.4f} - Balanced Acc: {epoch_acc:.2f}%")

    # 8. Save the Final Weights
    torch.save(model.state_dict(), "pcb_fault_bnn_v16.pth")
    print("✅ Model saved as pcb_fault_bnn_v16.pth")

if __name__ == "__main__":
    train_pcb_bnn()
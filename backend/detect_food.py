from ultralytics import YOLO

# Load official YOLOv8 model (auto-download)
model = YOLO("yolov8n.pt")

# Run detection on image
results = model("test.jpg")

foods = []

# Food-related classes (YOLOv8 default)
FOOD_CLASSES = [
    "pizza", "banana", "apple", "sandwich",
    "orange", "cake", "donut", "hot dog"
]

# Extract detected food items
for r in results:
    for box in r.boxes:
        cls_id = int(box.cls[0])
        name = model.names[cls_id]
        if name in FOOD_CLASSES:
            foods.append(name)

# Remove duplicates & limit to max 10
foods = list(set(foods))[:10]

print("Detected foods:", foods)

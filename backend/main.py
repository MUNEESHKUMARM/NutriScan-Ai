from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from google import genai
import pandas as pd
from PIL import Image
import io
import os

# ---------------- APP ----------------
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------- GEMINI ----------------
API_KEY = "AIzaSyCD9uqSMbU6erc5QBRD00lV9RbOQr9JI1o"
client = genai.Client(api_key=API_KEY)

# ---------------- CSV LOAD ----------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(BASE_DIR, "food nutrient dataset.csv")

try:
    df = pd.read_csv(csv_path)
    df.columns = df.columns.str.strip()
    print("✅ CSV Loaded")
except Exception as e:
    print("❌ CSV error:", e)
    df = None


def get_csv_nutrition(food_name: str):
    if df is None:
        return None

    match = df[df["Description"].str.contains(food_name.upper(), na=False)]
    if match.empty:
        return None

    row = match.iloc[0]
    return {
        "calories": f"{row['Calories']} kcal",
        "protein": f"{row['Protein']} g",
        "fat": f"{row['TotalFat']} g",
        "carbs": f"{row['Carbohydrate']} g",
    }


# ---------------- API ----------------
@app.post("/predict")
async def predict_food(image: UploadFile = File(...)):
    try:
        # Read image
        image_bytes = await image.read()
        img = Image.open(io.BytesIO(image_bytes))

        # ✅ CORRECT MODEL (THIS IS THE FIX)
        response = client.models.generate_content(
            model="models/gemini-1.0-pro-vision",
            contents=[
                "Identify the food in this image. Reply ONLY with the food name.",
                img
            ],
        )

        # Clean output
        food_name = response.text.strip()
        food_name = food_name.replace("*", "").replace("Food:", "").strip()
        print("🍽️ AI:", food_name)

        if not food_name:
            return {"error": "Food not detected"}

        nutrition = get_csv_nutrition(food_name)

        if nutrition:
            return {
                "food": food_name,
                "accuracy": "High (Gemini Vision)",
                "calories": nutrition["calories"],
                "protein": nutrition["protein"],
                "fat": nutrition["fat"],
                "carbs": nutrition["carbs"],
                "advice": "Data from CSV dataset",
            }

        return {
            "food": food_name,
            "accuracy": "Gemini Vision",
            "calories": "Not Available",
            "protein": "Not Available",
            "fat": "Not Available",
            "carbs": "Not Available",
            "advice": "Food detected but not found in dataset",
        }

    except Exception as e:
        print("❌ BACKEND ERROR:", e)
        return {"error": str(e)}


# ---------------- RUN ----------------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)

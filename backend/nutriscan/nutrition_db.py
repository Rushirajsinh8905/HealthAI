# ============================================================
# NUTRISCAN v2 — ADVANCED NUTRITION DATABASE
# File: nutriscan/nutrition_db_v2.py
#
# Upgrades over v1:
# - Per-food-type portion gram ranges (not one-size-fits-all)
# - Realistic portion gram values from restaurant/home serving research
# - Fiber, sodium, sugar added
# - Meal type classification (snack, main, dessert)
# - Caloric density category (light, moderate, heavy)
# ============================================================

from typing import Dict, List, Optional, Tuple

# ── Per-100g nutrition values ─────────────────────────────────
# Sources: USDA FoodData Central + NIN India food composition tables
# All values are for COOKED/SERVED state (not raw)

NUTRITION_PER_100G: Dict[str, Dict] = {

    # ── 0: fried_rice ─────────────────────────────────────────
    'fried_rice': {
        'display_name': 'Fried Rice',
        'calories': 163, 'protein': 3.5, 'carbs': 26.0,
        'fat': 4.9,  'fiber': 0.9, 'sugar': 0.5, 'sodium': 420,
        'meal_type': 'main', 'density': 'moderate',
    },

    # ── 1: garlic_bread ───────────────────────────────────────
    'garlic_bread': {
        'display_name': 'Garlic Bread',
        'calories': 290, 'protein': 7.2, 'carbs': 39.0,
        'fat': 12.0, 'fiber': 1.8, 'sugar': 2.1, 'sodium': 540,
        'meal_type': 'snack', 'density': 'heavy',
    },

    # ── 2: samosa ─────────────────────────────────────────────
    'samosa': {
        'display_name': 'Samosa',
        'calories': 262, 'protein': 4.7, 'carbs': 28.0,
        'fat': 14.5, 'fiber': 2.1, 'sugar': 1.2, 'sodium': 380,
        'meal_type': 'snack', 'density': 'heavy',
    },

    # ── 3: waffles ────────────────────────────────────────────
    'waffles': {
        'display_name': 'Waffles',
        'calories': 291, 'protein': 7.9, 'carbs': 37.0,
        'fat': 13.4, 'fiber': 1.3, 'sugar': 8.0, 'sodium': 490,
        'meal_type': 'breakfast', 'density': 'heavy',
    },

    # ── 4: pizza ──────────────────────────────────────────────
    'pizza': {
        'display_name': 'Pizza (cheese)',
        'calories': 266, 'protein': 11.4, 'carbs': 33.0,
        'fat': 10.4, 'fiber': 2.3, 'sugar': 3.6, 'sodium': 598,
        'meal_type': 'main', 'density': 'heavy',
    },

    # ── 5: hamburger ──────────────────────────────────────────
    'hamburger': {
        'display_name': 'Hamburger',
        'calories': 295, 'protein': 17.0, 'carbs': 24.0,
        'fat': 14.0, 'fiber': 1.3, 'sugar': 5.0, 'sodium': 512,
        'meal_type': 'main', 'density': 'heavy',
    },

    # ── 6: caesar_salad ───────────────────────────────────────
    'caesar_salad': {
        'display_name': 'Caesar Salad',
        'calories': 90,  'protein': 4.8, 'carbs': 6.0,
        'fat': 5.8,  'fiber': 1.5, 'sugar': 1.2, 'sodium': 290,
        'meal_type': 'main', 'density': 'light',
    },

    # ── 7: omelette ───────────────────────────────────────────
    'omelette': {
        'display_name': 'Omelette',
        'calories': 154, 'protein': 10.6, 'carbs': 1.6,
        'fat': 11.7, 'fiber': 0.0, 'sugar': 0.8, 'sodium': 342,
        'meal_type': 'breakfast', 'density': 'moderate',
    },

    # ── 8: apple_pie ──────────────────────────────────────────
    'apple_pie': {
        'display_name': 'Apple Pie',
        'calories': 237, 'protein': 2.4, 'carbs': 34.0,
        'fat': 11.0, 'fiber': 1.5, 'sugar': 16.0, 'sodium': 270,
        'meal_type': 'dessert', 'density': 'heavy',
    },
}

# ── Per-food realistic portion gram ranges ────────────────────
# Based on:
# - Restaurant standard serving sizes
# - Home cooking typical servings
# - ICMR portion size guidelines (India)
# Format: (small_g, medium_g, large_g)

PORTION_GRAMS: Dict[str, Tuple[int, int, int]] = {
    # (small, medium, large) in grams

    # Rice dishes — rice expands a lot, medium plate = 250g
    'fried_rice':    (150, 250, 400),

    # Bread items — per piece/serving
    'garlic_bread':  (60,  100, 160),   # 1-2 slices

    # Snacks — samosa is typically 1-2 pieces
    'samosa':        (65,  120, 180),   # 1 medium / 2 medium / 3 medium

    # Breakfast items
    'waffles':       (75,  130, 200),   # 1 waffle / 1.5 / 2

    # Pizza — per slice / multiple slices
    'pizza':         (100, 200, 320),   # 1 slice / 2 slices / 3 slices

    # Burger — standard sizes
    'hamburger':     (140, 200, 280),   # small / regular / double

    # Salad — bowl sizes
    'caesar_salad':  (120, 220, 360),   # side / main / large

    # Omelette — by egg count
    'omelette':      (80,  130, 200),   # 1 egg / 2 egg / 3 egg

    # Pie — per slice
    'apple_pie':     (90,  150, 220),   # thin / regular / large slice
}

# ── Portion thresholds by food type ──────────────────────────
# How much of the image (area ratio) maps to which portion size
# Different foods need different thresholds:
# - A pizza usually fills more of the frame than a samosa
# - A salad bowl looks bigger but is lighter

PORTION_THRESHOLDS: Dict[str, Tuple[float, float]] = {
    # (medium_threshold, large_threshold)
    # below medium_threshold → small
    # between thresholds → medium
    # above large_threshold → large

    'fried_rice':    (0.20, 0.50),
    'garlic_bread':  (0.15, 0.40),
    'samosa':        (0.08, 0.25),  # samosa is small, fills less frame
    'waffles':       (0.20, 0.50),
    'pizza':         (0.25, 0.55),  # pizza slices are large
    'hamburger':     (0.20, 0.50),
    'caesar_salad':  (0.25, 0.55),
    'omelette':      (0.20, 0.50),
    'apple_pie':     (0.15, 0.40),
}

# Default thresholds for unknown classes
DEFAULT_THRESHOLDS = (0.20, 0.50)


def estimate_portion_from_bbox(
    food_name: str,
    bbox_x1: float,
    bbox_y1: float,
    bbox_x2: float,
    bbox_y2: float,
    img_width:  int,
    img_height: int,
) -> Tuple[str, int, float]:
    """
    Estimates portion size from bounding box area.

    Args:
        food_name: Detected food class name
        bbox_x1/y1/x2/y2: Bounding box pixel coords
        img_width/height: Full image dimensions

    Returns:
        Tuple of (portion_label, estimated_grams, area_ratio)
    """
    # Step 1: Calculate bounding box area as fraction of image
    box_w = max(0, bbox_x2 - bbox_x1)
    box_h = max(0, bbox_y2 - bbox_y1)
    img_area = img_width * img_height

    if img_area == 0:
        return ('medium', PORTION_GRAMS.get(food_name, (120, 200, 320))[1], 0.0)

    area_ratio = (box_w * box_h) / img_area
    area_ratio = min(area_ratio, 1.0)  # cap at 100%

    # Step 2: Get food-specific thresholds
    med_thresh, large_thresh = PORTION_THRESHOLDS.get(
        food_name, DEFAULT_THRESHOLDS
    )

    # Step 3: Map area ratio → portion label
    if area_ratio < med_thresh:
        portion_label = 'small'
    elif area_ratio < large_thresh:
        portion_label = 'medium'
    else:
        portion_label = 'large'

    # Step 4: Get gram value for this food + portion
    grams_table = PORTION_GRAMS.get(food_name, (120, 200, 320))
    portion_idx = {'small': 0, 'medium': 1, 'large': 2}[portion_label]
    grams = grams_table[portion_idx]

    return (portion_label, grams, round(area_ratio, 4))


def lookup_nutrition(
    food_name: str,
    grams: int,
) -> Optional[Dict]:
    """
    Returns nutrition for a given food at a given gram weight.

    Args:
        food_name: Food class name from YOLO
        grams: Estimated portion weight in grams

    Returns:
        Dict with all nutrition values, or None if food not found
    """
    # Normalize name
    key = food_name.lower().strip().replace(' ', '_')

    if key not in NUTRITION_PER_100G:
        # Try partial match
        for db_key in NUTRITION_PER_100G:
            if key in db_key or db_key in key:
                key = db_key
                break
        else:
            return None

    base = NUTRITION_PER_100G[key]
    mult = grams / 100.0

    return {
        'food_name':    key,
        'display_name': base['display_name'],
        'grams':        grams,
        'calories':     round(base['calories'] * mult, 1),
        'protein':      round(base['protein']  * mult, 1),
        'carbs':        round(base['carbs']    * mult, 1),
        'fat':          round(base['fat']      * mult, 1),
        'fiber':        round(base.get('fiber',  0) * mult, 1),
        'sugar':        round(base.get('sugar',  0) * mult, 1),
        'sodium':       round(base.get('sodium', 0) * mult, 1),
        'meal_type':    base.get('meal_type', 'main'),
        'density':      base.get('density', 'moderate'),
    }


def calculate_meal_totals(
    detections: List[Dict],
    img_width:  int,
    img_height: int,
) -> Dict:
    """
    Main function: Takes YOLO detections → returns full nutrition JSON.

    Args:
        detections: List of YOLO detection dicts:
            [{
                food_name: str,
                confidence: float,
                bbox: [x1, y1, x2, y2],
                portion_override: str | None  (from user S/M/L selection)
            }]
        img_width/height: Original image dimensions

    Returns:
        Full structured nutrition response
    """
    items = []
    total_calories = 0.0
    total_protein  = 0.0
    total_carbs    = 0.0
    total_fat      = 0.0
    total_fiber    = 0.0
    not_found      = 0

    for det in detections:
        food_name  = det.get('food_name', '')
        confidence = det.get('confidence', 1.0)
        bbox       = det.get('bbox', [0, 0, img_width, img_height])
        override   = det.get('portion_override')  # user manual S/M/L

        x1, y1, x2, y2 = bbox[0], bbox[1], bbox[2], bbox[3]

        # ── Portion estimation ────────────────────────────────
        auto_portion, auto_grams, area_ratio = estimate_portion_from_bbox(
            food_name, x1, y1, x2, y2, img_width, img_height
        )

        # User override takes priority over auto estimate
        if override in ('small', 'medium', 'large'):
            portion_label = override
            grams_table   = PORTION_GRAMS.get(food_name, (120, 200, 320))
            idx           = {'small': 0, 'medium': 1, 'large': 2}[override]
            grams         = grams_table[idx]
        else:
            portion_label = auto_portion
            grams         = auto_grams

        # ── Nutrition lookup ──────────────────────────────────
        nutrition = lookup_nutrition(food_name, grams)

        if nutrition is None:
            not_found += 1
            items.append({
                'food_name':    food_name,
                'display_name': food_name.replace('_', ' ').title(),
                'confidence':   round(confidence, 3),
                'portion':      portion_label,
                'grams':        grams,
                'area_ratio':   area_ratio,
                'bbox':         bbox,
                'found_in_db':  False,
                'calories': 0, 'protein': 0,
                'carbs': 0,    'fat': 0,
                'fiber': 0,    'sugar': 0, 'sodium': 0,
            })
            continue

        total_calories += nutrition['calories']
        total_protein  += nutrition['protein']
        total_carbs    += nutrition['carbs']
        total_fat      += nutrition['fat']
        total_fiber    += nutrition['fiber']

        items.append({
            **nutrition,
            'confidence':  round(confidence, 3),
            'area_ratio':  area_ratio,
            'bbox':        bbox,
            'auto_portion': auto_portion,
            'found_in_db': True,
        })

    # ── Health summary ────────────────────────────────────────
    health_rating = _rate_meal(total_calories, total_protein, total_fat)

    return {
        'items':           items,
        'total_calories':  round(total_calories, 1),
        'total_protein':   round(total_protein,  1),
        'total_carbs':     round(total_carbs,    1),
        'total_fat':       round(total_fat,      1),
        'total_fiber':     round(total_fiber,    1),
        'items_detected':  len(detections),
        'items_in_db':     len(detections) - not_found,
        'items_not_found': not_found,
        'health_summary':  health_rating,
    }


def _rate_meal(calories: float, protein: float, fat: float) -> Dict:
    """Simple meal health rating for the Flutter UI."""
    if calories == 0:
        return {'rating': 'unknown', 'label': 'No data', 'color': 'gray'}

    # Protein ratio check (>15% of calories from protein = good)
    protein_cals   = protein * 4
    protein_ratio  = protein_cals / calories if calories > 0 else 0

    # Fat ratio check (>40% of calories from fat = high)
    fat_cals  = fat * 9
    fat_ratio = fat_cals / calories if calories > 0 else 0

    if calories < 400 and fat_ratio < 0.35:
        return {'rating': 'excellent', 'label': 'Light & healthy', 'color': 'green'}
    elif calories < 700 and fat_ratio < 0.40 and protein_ratio > 0.15:
        return {'rating': 'good', 'label': 'Balanced meal', 'color': 'teal'}
    elif calories < 900 and fat_ratio < 0.45:
        return {'rating': 'moderate', 'label': 'Moderate meal', 'color': 'amber'}
    else:
        return {'rating': 'heavy', 'label': 'Heavy meal', 'color': 'red'}

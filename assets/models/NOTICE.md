# Third-party model notice

VYRO includes Google's AIY food classification LiteRT model, `aiy/vision/classifier/food_V1/1` (`aiy_food_v1.tflite`), and the matching label map (`aiy_food_v1_labels.csv`). The model is distributed under Apache License 2.0; see `APACHE-2.0.txt`.

- Model card: <https://www.kaggle.com/models/google/aiy/tfLite/vision-classifier-food-v1/1>
- Original model identifier: <https://tfhub.dev/google/aiy/vision/classifier/food_V1/1>
- Label map: <https://www.gstatic.com/aihub/tfhub/labelmaps/aiy_food_V1_labelmap.csv>
- Model file SHA-256: `03DD6D9129501F97BE00775D9E17B5D9AD13BE730149352ADB8F4CA953B7A650`

The model predicts one dish category from 2,023 food classes plus background. Its model card says it is skewed toward North American foods, assumes a well-cropped dish, and must not be used to infer ingredients, allergens or nutrition. VYRO presents ranked hypotheses for confirmation. It does not estimate portion size or nutrition from an image. No Portuguese-food evaluation has been completed; confidence values are model scores, not validated accuracy estimates.

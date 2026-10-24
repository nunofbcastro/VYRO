# Third-party model notice

VYRO includes Google's AIY food classification LiteRT model, `aiy/vision/classifier/food_V1/1` (`aiy_food_v1.tflite`), and the matching label map (`aiy_food_v1_labels.csv`). The model is distributed under Apache License 2.0; see `APACHE-2.0.txt`.

- Model card: <https://www.kaggle.com/models/google/aiy/tfLite/vision-classifier-food-v1/1>
- Original model identifier: <https://tfhub.dev/google/aiy/vision/classifier/food_V1/1>
- Label map: <https://www.gstatic.com/aihub/tfhub/labelmaps/aiy_food_V1_labelmap.csv>
- Model file SHA-256: `03DD6D9129501F97BE00775D9E17B5D9AD13BE730149352ADB8F4CA953B7A650`

The model predicts one dish category from 2,023 food classes plus background. Its model card says it is skewed toward North American foods, assumes a well-cropped dish, and must not be used to infer ingredients, allergens or nutrition. VYRO presents ranked hypotheses for confirmation. It does not estimate portion size or nutrition from an image. No Portuguese-food evaluation has been completed; confidence values are model scores, not validated accuracy estimates.

VYRO also includes Google's MoveNet SinglePose Lightning float16 LiteRT model, `movenet_lightning_fp16.tflite`, distributed under Apache License 2.0; see `APACHE-2.0.txt`.

- Model card: <https://storage.googleapis.com/movenet/MoveNet.SinglePose%20Model%20Card.pdf>
- Official model: <https://tfhub.dev/google/lite-model/movenet/singlepose/lightning/tflite/float16/4>
- SHA-256: `0FAC2226112D0371903CA86E3853CEC24EF603A0B2F96F589B180F0EBDD135AB`

MoveNet returns 17 single-person landmarks with confidence scores. Pose landmarks are ephemeral and are not persisted. The squat counter uses smoothed knee-angle thresholds as an approximate repetition signal; it does not assess exercise form or certify safety.

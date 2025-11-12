Summary

This project used BigQuery ML and a Kaggle version of the U.S. carrier on-time performance dataset to explore two operational questions for airlines: how well we can predict arrival delays with regression, and how well we can flag potential diversions with classification.

I built a canonical view of the Kaggle data in BigQuery, then trained a baseline logistic regression model and an engineered model (with route and delay buckets) to predict diverted. Because the label is extremely rare, a big part of the work was understanding how metrics behave under class imbalance and how to choose a practical threshold rather than relying on the default 0.5.

Key Learnings

Class imbalance dominates behavior.
Diversions are on the order of ~1 in hundreds of thousands of flights. Both baseline and engineered logistic models showed ROC AUC ≈ 0.69 but precision, recall, and F1 ≈ 0 at the default threshold, simply because the model almost never predicted a positive case.

Good ranking does not imply good default decisions.
The models provided non-trivial separation (reasonable AUC and low log loss), meaning they can rank flights by risk, but at 0.5 they effectively act as “always predict 0” classifiers. This showed the gap between probability quality and operational decision quality.

Feature engineering helped slightly but didn’t fix rarity.
Adding route (origin-dest), a bucketized departure delay, and day-of-week produced an engineered model with metrics very close to the baseline. It confirmed that handling imbalance (weights/thresholds) matters more than small feature tweaks at this stage.

Where the Model Failed

Missed all (or almost all) diversions at 0.5.
Confusion matrices on the eval split had TP = 0, FP = 0–1, FN = 900+, TN = 390k+. Operationally, this means the model is useless as a binary decision engine at the default cutoff: it would never trigger proactive diversion prep.

Zero precision/recall made “headline” metrics misleading.
Accuracy stayed around 99.76%, which looks great on paper but mostly reflects the majority class. This was a useful reminder that, for rare events, accuracy and even F1 can be deceptive without digging into the confusion matrix and base rates.

Feature engineering alone wasn’t enough.
Even with more informative features, the model’s predicted probabilities remained so low that essentially none crossed the 0.5 line. The failure mode is structural: we need class weights, resampling, or explicit threshold tuning, not just more columns.

Threshold I’d Deploy & Rationale

In a realistic airline ops setting I would not deploy this model as a hard yes/no “divert vs not” decision tool. Instead, I’d use it to generate a high-risk watchlist:

I would start with a threshold around 0.25 on the predicted probability of diversion:

This is low enough to surface more of the few true diversions.

It keeps the number of flagged flights small enough that an ops team can review them manually.

Operationally, false negatives are more expensive than false positives:

FP: extra monitoring and some wasted analyst time.

FN: missed opportunity to pre-position staff/gates and communicate with customers.

For a decision-support tool, I’d aim for an acceptable FN rate of ~10–20% (catching 80–90% of diversions), even if that means tolerating a fair number of false alarms on the watchlist.

Personal Reflection

This project forced me to go beyond “does the model train and give a high AUC?” and think about how it would actually be used in operations. I learned how easily a rare label can produce great-looking metrics but terrible real-world behavior, and how important it is to choose thresholds and metrics that line up with the business cost of FP vs FN.
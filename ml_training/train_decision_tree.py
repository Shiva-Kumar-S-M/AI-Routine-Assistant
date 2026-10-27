#!/usr/bin/env python3
import json
import numpy as np
from sklearn.tree import DecisionTreeClassifier, export_text
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix

def generate_synthetic_dataset(num_samples=2000):
    np.random.seed(42)
    X = []
    y = []

    for _ in range(num_samples):
        hour_of_day = np.random.randint(0, 24)
        duration_seconds = np.random.randint(10, 7200)
        category_code = np.random.choice([0, 1, 2], p=[0.3, 0.3, 0.4]) # 0: productive, 1: neutral, 2: distracting
        rolling_distraction_2h = np.random.randint(0, 5400)
        days_used_this_hour = np.random.randint(1, 8)

        # Label logic based on behavioral target rules:
        # Label 1: Distraction Alert if distracting app & rolling 2h >= 2400s (40 mins) OR session duration > 3600s
        # Label 2: Routine Reminder if days_used_this_hour >= 3 and session start in prime time
        # Label 0: Normal / No Alert
        if category_code == 2 and (rolling_distraction_2h >= 2400 or duration_seconds >= 3600):
            label = 1
        elif days_used_this_hour >= 3 and (8 <= hour_of_day <= 22) and duration_seconds > 300:
            label = 2
        else:
            label = 0

        X.append([hour_of_day, duration_seconds, category_code, rolling_distraction_2h, days_used_this_hour])
        y.append(label)

    return np.array(X), np.array(y)

def export_tree_to_json(tree, feature_names):
    tree_ = tree.tree_
    def recurse(node):
        if tree_.feature[node] != -2: # Not a leaf
            name = feature_names[tree_.feature[node]]
            threshold = float(tree_.threshold[node])
            return {
                "type": "node",
                "feature": name,
                "threshold": threshold,
                "left": recurse(tree_.children_left[node]),
                "right": recurse(tree_.children_right[node])
            }
        else:
            value = tree_.value[node][0]
            predicted_class = int(np.argmax(value))
            return {
                "type": "leaf",
                "class": predicted_class,
                "probabilities": (value / np.sum(value)).tolist()
            }
    return recurse(0)

def main():
    print("Generating synthetic usage dataset...")
    X, y = generate_synthetic_dataset(2500)

    feature_names = [
        "hour_of_day",
        "duration_seconds",
        "category_code",
        "rolling_distraction_2h",
        "days_used_this_hour"
    ]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    clf = DecisionTreeClassifier(max_depth=6, random_state=42)
    clf.fit(X_train, y_train)

    train_acc = clf.score(X_train, y_train)
    test_acc = clf.score(X_test, y_test)

    y_pred = clf.predict(X_test)

    print(f"\nModel Training Complete:")
    print(f"Train Accuracy: {train_acc * 100:.2f}%")
    print(f"Test Accuracy:  {test_acc * 100:.2f}%")
    print("\nConfusion Matrix:")
    print(confusion_matrix(y_test, y_pred))
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=["No Alert", "Distraction Alert", "Routine Reminder"]))

    # Export model to JSON
    tree_json = export_tree_to_json(clf, feature_names)
    with open("ml_training/decision_tree_model.json", "w") as f:
        json.dump(tree_json, f, indent=2)

    print("Exported trained Decision Tree structure to ml_training/decision_tree_model.json")

if __name__ == "__main__":
    main()

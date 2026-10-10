#stores the helper functions you need for your endpoints

# Function to get summary of the nutrition categories-- takes the percentage to see how close you are to the goal
def get_nutrition_stats(category, goal):
    return min(category/goal, 1.0) * 100 #doesnt go over 100%
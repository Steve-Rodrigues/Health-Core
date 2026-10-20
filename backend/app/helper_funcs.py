#stores the helper functions you need for your endpoints

# Function to get summary of the nutrition categories-- takes the percentage to see how close you are to the goal
def get_nutrition_stats(category, goal):
    if goal<=0:
        return 100.0 #no goal hit so treat it as met
    return round(min(category/goal, 1.0) * 100, 1) #doesnt go over 100%, rounded to 1 decimal
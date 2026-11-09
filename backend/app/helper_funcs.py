#stores the helper functions you need for your endpoints
from fastapi import HTTPException,status
import requests
from sqlalchemy import select, func, exists
from app.models import Workout, Workout_Set
#buckets for the program scoring-- programs at or below the users bucket are ones they can do
Experience_Buckets = {'beginner':0, 'intermediate':1, 'expert':2} #dict to grab only the programs that are at least at the level the user answered
Equipment_Buckets = {'bodyweight':0, 'home':1,'gym':2} #each level includes the ones before it
# Function to get summary of the nutrition categories-- takes the percentage to see how close you are to the goal
def get_nutrition_stats(category, goal):
    if goal<=0:
        return 100.0 #no goal hit so treat it as met
    return round(min(category/goal, 1.0) * 100, 1) #doesnt go over 100%, rounded to 1 decimal

#function to get the bucket for the equipment level the user is at in their survey response
def get_equipment_level(equip_list):
    home_points = {'dumbbell':3, 'kettlebells':2, 'medicine ball':1, 'exercise ball':1} #each one the user has adds to their points
    gym_points = {'barbell':4, 'cable':4,'machine':4, 'e-z curl bar':2}
    HOME_POINTS_NEEDED = 4 #hits the big ones for home
    GYM_POINTS_NEEDED = 8 #hits needed ones for gym
    gym_points_found,home_points_found = 0,0

    for item in equip_list:
        if item in home_points: home_points_found += home_points[item]
    for item in equip_list:
        if item in gym_points: gym_points_found += gym_points[item]
    #returning the bracket of equipment the user will be put into based on their points
    if gym_points_found >= GYM_POINTS_NEEDED and home_points_found >= HOME_POINTS_NEEDED:
        return 'gym'
    elif home_points_found >= HOME_POINTS_NEEDED:
        return 'home'
    else:
        return 'bodyweight'
#returns a weighted score for each program based on how it aligns with the users preferences-- score lets us give the best match
#score is from 0-100, each proportion of the user choices the program fulfills scales the weights and then we add the weights for the score
def score_program(program, user_equip_level, user_exp_level, user_days_level, user_goal):
    WEIGHTS = {'goal':55, 'experience':25, 'days': 12, 'equipment': 8} #how much each category is weighted
    #each category is the result of subtracting 1 by the programs bucket divided by the largest possible gap 
    #the gaps are diff between the users bucket and the program bucket, gap is best when its 0 because means it was exact to the percentage will be 1
    experience_gap = Experience_Buckets[user_exp_level] - Experience_Buckets[program.difficulty]
    equipment_gap = Equipment_Buckets[user_equip_level] - Equipment_Buckets[program.equipment_level]
    days_gap = user_days_level - program.number_of_days

    #the scales are 1 - gap/(biggest possible gap) which gives the percentage it gives of fulfillment(want it to be 1)
    goal_scale = 1.0 if program.goal == user_goal else 0.0 #the goal either is the same or different (most important weight)
    experience_scale = 1 - experience_gap/2
    equipment_scale = 1 - equipment_gap/2
    days_scale = 1 - days_gap/4

    return (
        goal_scale*WEIGHTS['goal']+experience_scale*WEIGHTS['experience']+equipment_scale*WEIGHTS['equipment']+days_scale*WEIGHTS['days']
    )

#helper function to normalize the barcodes so if they are length 12 we add a 0 in front and only accept length of 8,13,14
#8 is small packages, 13 is most barcodes, and 14 is multipack items
def normalize_barcode(code):
    stripped_code = ''.join(c for c in code if c.isdigit())#strips the spaces if any in the code
    if len(stripped_code) == 12:
        stripped_code = '0'+stripped_code #add 0 to the front so its the 13 length style
    if len(stripped_code) not in (8,13,14): raise HTTPException(400, 'Code not a valid length')
    return stripped_code
#fetching from the barcode api for the info for a certain barcode
def fetch_barcode(code):
    try:
        url = f'https://world.openfoodfacts.org/api/v2/product/{code}.json'
        request = requests.get(url, 
                               params={'fields':'code,product_name,serving_quantity,nutriments'},
                               headers={'User-Agent':'HealthCore/1.0(stevie.rodrigues27@gmail.com)'},
                               timeout=10)
        if request.status_code == 404: raise HTTPException(404, 'Barcode not found')
        data = request.json()
    except requests.exceptions.RequestException:
        raise HTTPException(503, 'Could not complete request')
    if data.get('status') != 1: raise HTTPException(404, 'Barcode not found')
    return data #this holds the object with the data from the request



#cleans up a user's unfinished workouts that don't belong to the program they're on now (ex: they switched programs mid workout)
#workouts with no sets logged are just abandoned starts so we delete them, ones with sets get marked finished so that data isnt lost
#pass keep_program_id to leave open workouts for that program alone, or None to clean up all of them-- caller commits
def close_stale_workouts(db, user_id, keep_program_id=None):
    query = select(Workout).where(Workout.user_id==user_id, Workout.completed_at.is_(None))
    if keep_program_id is not None:
        query = query.where(Workout.program_id.is_distinct_from(keep_program_id)) #also catches workouts whose program was deleted (NULL)
    for workout in db.scalars(query).all():
        has_sets = db.scalar(select(exists().where(Workout_Set.workout_id==workout.id)))
        if has_sets: workout.completed_at = func.now()
        else: db.delete(workout)

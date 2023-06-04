"""Birdbyt"""

load('cache.star', 'cache')
load('encoding/base64.star', 'base64')
load('encoding/json.star', 'json')
load('http.star', 'http')
load('humanize.star', 'humanize')
load('random.star', 'random')
load('render.star', 'render')
load('schema.star', 'schema')
load("secret.star", 'secret')
load('time.star', 'time')

EBIRD_API_KEY = 'AV6+xWcECVOVS+y/jlkVqyE0oxKa9Ql7M/h05Xh+ilG7K+8ELfdgmPX6FPFcDdDuEz5PSbWO1sNs+XjhuS8Bm4qbT00tO0A3DIG5mDo78bAg2dhYVIhPyp/AyiCDzVadqN2KKGduX2NKdihnCyn4NWHW'
EBIRD_URL = 'https://api.ebird.org/v2'
MAX_API_RESULTS = '100'

# Config defaults
DEFAULT_LOCATION = {
    # Easthampton, MA
    'lat': '42.266',
    'lng': '-72.668',
    'timezone': 'America/New_York'
}
DEFAULT_DISTANCE = '2'
DEFAULT_BACK = '2'

# When there are no birds
NO_BIRDS = {
    'bird': 'No birds found',
    'loc': 'Try increasing search distance'
}


def get_params(config):
    """Get params for e-birds request.

    Args:
      config: config dict passed from the app
    Returns:
      params: dict
    """

    params = {}

    location = config.get('location')
    loc = json.decode(location) if location else DEFAULT_LOCATION
    params['lat'] = loc['lat']
    params['lng'] = loc['lng']
    params['tz'] = loc['timezone'] if time.is_valid_timezone(loc['timezone']) else DEFAULT_LOCATION['timezone']

    params['dist'] = config.get('distance') or DEFAULT_DISTANCE
    params['back'] = config.get('back') or DEFAULT_BACK
    params['maxResults'] = MAX_API_RESULTS

    return params


def get_recent_birds(params, ebird_key):
    """Request a list of recent birds.

    Args:
      params: dictionary of parameters for the ebird API call
      ebird_key: ebird API key

    Returns:
      ebird sightings data
    """

    # Do we already have cached data for this set of API params?
    cache_key = '-'.join(params.values())
    sightings = cache.get(cache_key)
    if sightings != None:
        print('Cache hit:', cache_key)  # buildifier: disable=print
        return json.decode(sightings)

    # Nothing cached, so call the API
    ebird_recent_obs_route = '/data/obs/geo/recent'
    print('Cache miss:', cache_key, '\nCalling ', ebird_recent_obs_route)  # buildifier: disable=print
    url = EBIRD_URL + ebird_recent_obs_route
    headers = {'X-eBirdApiToken': ebird_key}

    response = http.get(url, params=params, headers=headers)

    # e-bird API request failed
    if response.status_code != 200:
        return [{
            'comName': 'Bird error!',
            'locName': 'API status code = ' + str(response.status_code)
        }]

    sightings = response.json()
    cache.set(cache_key, json.encode(sightings), ttl_seconds=3600)
    return sightings


def format_sighting(sightings, tz):
    """Parse ebird response data.

    Args:
      sightings: list of ebird sightings
      tz: application's timezone

    Returns:
      a dictionary representing a single bird sighting
    """

    sighting = {}

    number_of_sightings = len(sightings)
    print('number of sightings: ', number_of_sightings)  # buildifier: disable=print

    # request succeeded, but no birds found
    if number_of_sightings == 0:
        sighting = NO_BIRDS
        return sighting
    
    # grab a random bird sighting from ebird response
    random_sighting = random.number(0, number_of_sightings - 1)
    data = sightings[random_sighting]

    sighting['bird'] = data.get('comName') or 'Unknown bird'
    sighting['loc'] = data.get('locName') or 'Location unknown'
    if data.get('obsDt'):
        sighting['date'] = time.parse_time(data.get('obsDt'), format='2006-01-02 15:04', location=tz)
    
    return sighting


def get_sighting_day(sighting_date):
    """Return day of sighting.

    Given the date object of a bird sighting, return corresponding day of
    the week. Because sighting data is coming from eBird's nearby observations
    API, we'll assume the sightings time zone corresponds to that of local time

    Args:
      sighting_date: full date/time of a bird sighting

    Returns:
      a string representing the sighting's day of the week (or today)
    """

    days = {
        0: 'Sunday',
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday'
    }

    day_of_week = humanize.day_of_week(sighting_date)

    if day_of_week == humanize.day_of_week(time.now()):
        sighting_day = 'Today'
    else:
        sighting_day = days[day_of_week]

    return sighting_day

def format_bird_name(bird):
    """Format bird name for display.

    Args:
      bird: name of the bird returned from API

    Returns:
      bird name modified for Tidbyt display
    """

    # Hard-code some formatting until I feel like futzing with
    # the layout more
    print('bird name: ', bird)  # buildifier: disable=print
    bird = bird.replace('Hummingbird', 'Humming-bird')
    bird = bird.replace('catcher', '-catcher')
    bird = bird.replace('pecker', '-pecker')
    bird = bird.replace('thrush', '-thrush')

    # Wrapped text widget doesn't break on a hyphen, so force a newline
    # (many birds have hyphenated names, as it turns out)
    bird = bird.replace('-', '-\n')
    return bird


def get_scroll_text(sighting):
    """Return a text string to scroll in the bottom marquee.

    Args:
      sighting: a dictionary representing a single bird sighting

    Returns:
      text to scroll at the bottom of the Tidbyt display
    """

    if sighting.get('date'):
        day = get_sighting_day(sighting['date'])
        scroll_text = day + ': ' + sighting.get('loc')
    else:
        scroll_text = sighting.get('loc')
    
    return scroll_text
 

def main(config):
    """Update config.

    Args:
      config: config dict passed from the app

    Returns:
      rendered WebP image for Tidbyt display
    """
    ebird_key = secret.decrypt(EBIRD_API_KEY) or config.get('ebird_api_key')
    params = get_params(config)
    response = get_recent_birds(params, ebird_key)
    sighting = format_sighting(response, params['tz'])

    return render.Root(
        render.Column(
            children=[
                render.Row(
                    children=[
                        render.Column(     
                            children=[
                                render.Box(
                                    width=18,
                                    height=25,
                                    child=render.Image(src=PURPLE_BIRD_IDLE)),
                            ]
                        ),
                        render.Box(
                            height=25,
                            padding=1,
                            child=render.Marquee(
                                scroll_direction='vertical',
                                align='center',
                                height=25,
                                child=render.WrappedText(
                                    align='left',
                                    content=format_bird_name(sighting.get('bird'))
                                )
                            )
                        )
                    ]
                ),
                render.Row(
                    expanded=True,
                    cross_align='end',
                    children=[
                        render.Box(
                            color='043927',
                            child=render.Marquee(
                                width=64,
                                child=render.Text(
                                    color='fefbbd',
                                    font='tom-thumb',
                                    content=get_scroll_text(sighting)
                                )
                            )
                        )
                    ]
                )
            ]
        )
    )


def get_schema():
    """Return the schema needed for Tidybyt community app installs.

    Returns:
      Tidbyt schema
    """

    list_back = ['1', '2', '3', '4', '5', '6']
    options_back = [
        schema.Option(display = item, value = item)
        for item in list_back
    ]

    list_distance = ['1', '2', '5', '10', '25']
    options_distance = [
        schema.Option(display = item, value = item)
        for item in list_distance
    ]

    return schema.Schema(
        version = '1',
        fields = [
            schema.Location(
                id = 'location',
                name = 'Location',
                desc = 'Location to search for bird sightings.',
                icon = 'locationDot',
            ),
            schema.Dropdown(
                id = 'distance',
                name = 'Distance',
                desc = 'Search radius from location (km)',
                icon = 'dove',
                default = DEFAULT_DISTANCE,
                options = options_distance
            ),
            schema.Dropdown(
                id = 'back',
                name = 'Back',
                desc = 'Number of days back to fetch bird sightings.',
                icon = 'calendarDays',
                default = DEFAULT_BACK,
                options = options_back
            )
        ],
    )


#------------------------------------------------------------------------
# Assets
# (until Tidbyt/pixlet has the concept of a separate assets folder, 
# images and gifs are stored in the .star file as encoded binary data)
#------------------------------------------------------------------------
PURPLE_BIRD_IDLE = base64.decode("""
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
""")

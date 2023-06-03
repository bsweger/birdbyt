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

BIRD_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABOElEQVQ4T6VSPU8CMRh+uhBEHEgMGhCGczl3SdhcNXF2cnPG2d8Bi79BFzdnFkKCO7foAhovITEmBxwM1j4lvdxhDy7xTdqk7fP1vqnAP0tk5bunHbnCSngvtxEvk4Db6Mhy1YEGq80fv8IbrES2CriNtiIfo17dxegjQPfpEs3zB3xPfAwHLbFRgLHLNQf1ShGj9wCLxRT95ys0Lx61c+/uenMCRj84clCr0H2KZTiLRvY1+cTwppUusI3sqfipM1gnE2jc6WzIfwRI5GU8Ns/++A2l/UPMZwFCtawCJBOUyxcSXyNO5oNVwJANkyIksoyzjaxbIDlfKGJHLVvRUarGwnkyusEqgbYS2NNnghPFiahZc9z8NDaDKMF6bwT/3EOKkxzE2TL1w+kHthGfrHHKLGBtPuPlL42CnW2DwIuFAAAAAElFTkSuQmCC
""")

# Config defaults
DEFAULT_LOCATION = {
    # Easthampton, MA
    'lat': '42.266',
    'lng': '-72.668'
}
DEFAULT_DISTANCE = '2'
DEFAULT_BACK = '2'

# When there are no birds
NO_BIRDS = {
    'bird': 'No birds found',
    'loc': 'Try increasing search distance',
    'date': time.now()
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
        return []

    sightings = response.json()
    cache.set(cache_key, json.encode(sightings), ttl_seconds=3600)
    return sightings


def format_sighting(sightings):
    """Parse ebird response data.

    Args:
      sightings: ebird sightings data

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

    sighting['bird'] = data.get('comName')
    sighting['loc'] = data.get('locName') or 'Location unknown'
    sighting['date'] = time.parse_time(data.get('obsDt'), format='2006-01-02 15:04')
    
    return sighting


def get_sighting_day(sighting_date):
    """Return day of sighting.

    Args:
      sighting_date: full date/time of a bird sighting

    Returns:
      a string representing the sighting's day of the week (or today)
    """

    days = {
        0: 'Monday',
        1: 'Tuesday',
        2: 'Wednesday',
        3: 'Thursday',
        4: 'Friday',
        5: 'Saturday',
        6: 'Sunday'
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

    day = get_sighting_day(sighting['date'])
    scroll_text = day + ': ' + sighting['loc']
    
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
    sighting = format_sighting(response)

    return render.Root(
        render.Column(
            children=[
                render.Row(
                    children=[
                        render.Box(
                            width=18,
                            height=25,
                            child=render.Image(src=BIRD_ICON)),
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
                                    offset=-1,
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

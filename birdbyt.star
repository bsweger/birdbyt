"""Birdbyt"""

load('cache.star', 'cache')
load("encoding/base64.star", "base64")
load('encoding/json.star', 'json')
load('http.star', 'http')
load('humanize.star', 'humanize')
load('random.star', 'random')
load('render.star', 'render')
load("secret.star", "secret")
load('time.star', 'time')

EBIRD_API_KEY = "AV6+xWcEv/YjkWNTF/Gyjx/ueAW476JLIwmwOHXQi8pNzE5Arbce6/bflzA0i0BIl/ocq1y/nNUFR/3lCZwUFmsbJ5s+R8YLlNNMmF1PNCi5IKgBaVDF8lUW+YFT7nUBkLXzt7JrorOsDGXBHejPq1tz"
EBIRD_URL = 'https://api.ebird.org/v2'
MAX_API_RESULTS = "100"

BIRD_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABOElEQVQ4T6VSPU8CMRh+uhBEHEgMGhCGczl3SdhcNXF2cnPG2d8Bi79BFzdnFkKCO7foAhovITEmBxwM1j4lvdxhDy7xTdqk7fP1vqnAP0tk5bunHbnCSngvtxEvk4Db6Mhy1YEGq80fv8IbrES2CriNtiIfo17dxegjQPfpEs3zB3xPfAwHLbFRgLHLNQf1ShGj9wCLxRT95ys0Lx61c+/uenMCRj84clCr0H2KZTiLRvY1+cTwppUusI3sqfipM1gnE2jc6WzIfwRI5GU8Ns/++A2l/UPMZwFCtawCJBOUyxcSXyNO5oNVwJANkyIksoyzjaxbIDlfKGJHLVvRUarGwnkyusEqgbYS2NNnghPFiahZc9z8NDaDKMF6bwT/3EOKkxzE2TL1w+kHthGfrHHKLGBtPuPlL42CnW2DwIuFAAAAAElFTkSuQmCC
""")

def get_params(config):
    """Get params for e-birds request.
    
    Args:
      config: config dict passed from the app
    Returns:
      params: dict
    """

    params = {}
    params['dist'] = config.get('distance') or '5'
    params['back'] = config.get('back') or '6'
    params['maxResults'] = MAX_API_RESULTS

    # Default the location to Easthampton, MA
    params['lat'] = config.get('lat') or '42.266757'
    params['lng'] = config.get('long') or '-72.66898'

    return params


def get_recent_birds(params, ebird_key):
    """Request a list of recent birds."""

    # Do we already have cached data for this set of API params?
    cache_key = '-'.join(params.values())
    sightings = cache.get(cache_key)
    if sightings != None:
        print("Cache hit:", cache_key)
        return json.decode(sightings)

    # Nothing cached, so call the API
    print("Cache miss:", cache_key)
    ebird_recent_obs_route = '/data/obs/geo/recent'
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
    """Parse ebird response data."""

    sighting = {}

    number_of_sightings = len(sightings)

    # request succeeded, but no data was returned
    if number_of_sightings == 0:
        sighting['bird'] = ['No recent sightings']
        return sighting
    
    # grab a random bird sighting from ebird response
    random_sighting = random.number(0, number_of_sightings - 1)
    data = sightings[random_sighting]

    sighting['bird'] = data.get('comName')
    sighting['loc'] = data.get('locName') or 'Location unknown'
    sighting['date'] = time.parse_time(data.get('obsDt'), format='2006-01-02 15:04')
    
    return sighting


def get_sighting_day(sighting_date):
    """Return day of sighting."""

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
    """Format bird name for display."""

    # Hard-code some formatting until I feel like futzing with
    # the layout more
    bird = bird.replace('Hummingbird', 'Humming-bird')
    bird = bird.replace('catcher', '-catcher')
    bird = bird.replace('pecker', '-pecker')

    # Wrapped text widget doesn't break on a hyphen, so force a newline
    # (many birds have hyphenated names, as it turns out)
    bird = bird.replace('-', '-\n')
    return bird


def get_scroll_text(sighting):
    """Return a text string to scroll in the bottom marquee."""

    day = get_sighting_day(sighting['date'])
    scroll_text = day + ': ' + sighting['loc']
    
    return scroll_text
 

def main(config):
    """Update config.
    
    Args:
      config: config dict passed from the app
    Returns:
      ???
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

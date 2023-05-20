"""Birdbyt"""

load('http.star', 'http')
load('humanize.star', 'humanize')
load('random.star', 'random')
load('render.star', 'render')
load("secret.star", "secret")
load('time.star', 'time')

EBIRD_API_KEY = "AV6+xWcEv/YjkWNTF/Gyjx/ueAW476JLIwmwOHXQi8pNzE5Arbce6/bflzA0i0BIl/ocq1y/nNUFR/3lCZwUFmsbJ5s+R8YLlNNMmF1PNCi5IKgBaVDF8lUW+YFT7nUBkLXzt7JrorOsDGXBHejPq1tz"
EBIRD_URL = 'https://api.ebird.org/v2'

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
    params['maxResults'] = '100'

    # Default the location to Easthampton, MA
    params['lat'] = config.get('lat') or '42.266757'
    params['lng'] = config.get('long') or '-72.66898'

    return params

def get_recent_birds(params, ebird_key):
    """Request a list of recent birds."""

    ebird_recent_obs_route = '/data/obs/geo/recent'
    url = EBIRD_URL + ebird_recent_obs_route
    headers = {'X-eBirdApiToken': ebird_key}

    response = http.get(url, params=params, headers=headers)
    return response

def get_sighting(response):
    """Parse ebird response."""

    sighting = {}

    # e-bird API request failed
    if response.status_code != 200:
        sighting['bird'] = 'Error retrieving birds'
        return sighting

    number_of_sightings = len(response.json())

    # request succeeded, but no data was returned
    if number_of_sightings == 0:
        sighting['bird'] = ['No recent sightings']
        return sighting
    
    # grab a random bird sighting from ebird response
    random_sighting = random.number(0, number_of_sightings - 1)
    data = response.json()[random_sighting]

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
    sighting = get_sighting(response)
    sighting_day = get_sighting_day(sighting['date'])
    
    return render.Root(
        render.Column(
            children=[
                render.Marquee(
                    width=64,
                    child=render.Text(
                        sighting.get('bird'),
                        color='ff8241'
                    ),
                ),
                render.Text(sighting_day),
                render.WrappedText(sighting.get('loc'))
            ]
        )
)


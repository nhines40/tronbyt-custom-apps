# NFL Game
# NFL counterpart to tronbyt/apps apps/mlb_game.
# Geometry intentionally follows MLB Game: 36px team panel + 28px info panel.

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

WHITE = "#ffffff"
BLACK = "#000000"

TEAM_BG = {
    "ARI":"#97233F", "ATL":"#A71930", "BAL":"#241773", "BUF":"#00338D", "CAR":"#0085CA", "CHI":"#0B162A", "CIN":"#FB4F14", "CLE":"#311D00",
    "DAL":"#003594", "DEN":"#FB4F14", "DET":"#0076B6", "GB":"#203731", "HOU":"#03202F", "IND":"#002C5F", "JAX":"#006778", "KC":"#E31837",
    "LV":"#111111", "LAC":"#0080C6", "LAR":"#003594", "MIA":"#008E97", "MIN":"#4F2683", "NE":"#002244", "NO":"#A08A58", "NYG":"#0B2265",
    "NYJ":"#125740", "PHI":"#004C54", "PIT":"#101820", "SF":"#AA0000", "SEA":"#002244", "TB":"#D50A0A", "TEN":"#0C2340", "WSH":"#5A1414",
}
TEAM_NAMES = {
    "ARI":"Arizona Cardinals", "ATL":"Atlanta Falcons", "BAL":"Baltimore Ravens", "BUF":"Buffalo Bills", "CAR":"Carolina Panthers", "CHI":"Chicago Bears", "CIN":"Cincinnati Bengals", "CLE":"Cleveland Browns",
    "DAL":"Dallas Cowboys", "DEN":"Denver Broncos", "DET":"Detroit Lions", "GB":"Green Bay Packers", "HOU":"Houston Texans", "IND":"Indianapolis Colts", "JAX":"Jacksonville Jaguars", "KC":"Kansas City Chiefs",
    "LV":"Las Vegas Raiders", "LAC":"Los Angeles Chargers", "LAR":"Los Angeles Rams", "MIA":"Miami Dolphins", "MIN":"Minnesota Vikings", "NE":"New England Patriots", "NO":"New Orleans Saints", "NYG":"New York Giants",
    "NYJ":"New York Jets", "PHI":"Philadelphia Eagles", "PIT":"Pittsburgh Steelers", "SF":"San Francisco 49ers", "SEA":"Seattle Seahawks", "TB":"Tampa Bay Buccaneers", "TEN":"Tennessee Titans", "WSH":"Washington Commanders",
}
THROWBACK = {
    "ATL":{"name":"Throwback","bg":"#A71930"}, "BUF":{"name":"Throwback","bg":"#00338D"}, "CHI":{"name":"1936 Throwback","bg":"#0B162A"}, "CLE":{"name":"Classic Throwback","bg":"#311D00"},
    "DAL":{"name":"Throwback","bg":"#002244"}, "DEN":{"name":"Orange Crush","bg":"#FB4F14"}, "DET":{"name":"Classic Throwback","bg":"#0076B6"}, "GB":{"name":"Classic Throwback","bg":"#203731"},
    "JAX":{"name":"Prowler Throwback","bg":"#006778"}, "MIA":{"name":"Throwback","bg":"#008E97"}, "MIN":{"name":"Classic Throwback","bg":"#4F2683"}, "NE":{"name":"Pat Patriot","bg":"#C60C30"},
    "NYG":{"name":"Classic Throwback","bg":"#0B2265"}, "NYJ":{"name":"Legacy Throwback","bg":"#125740"}, "PHI":{"name":"Kelly Green","bg":"#004953"}, "PIT":{"name":"1933 Throwback","bg":"#101820"},
    "SF":{"name":"94 Throwback","bg":"#AA0000"}, "SEA":{"name":"90s Throwback","bg":"#69BE28"}, "TB":{"name":"Creamsicle","bg":"#FF7900"}, "TEN":{"name":"Oilers Throwback","bg":"#418FDE"}, "WSH":{"name":"Super Bowl Era","bg":"#5A1414"},
}
THROWBACK_SCHEDULE = {"2026": {}}

def spacer_w(w): return render.Box(width=w, height=1)
def spacer_h(h): return render.Box(width=1, height=h)
def s(v, d=""): return v if v != None and type(v) == "string" else d
def i(v, d=0): return v if v != None and type(v) == "int" else d

def score_int(v):
    if type(v) == "int": return v
    if type(v) == "string" and v != "":
        for n in range(0, 100):
            if v == str(n): return n
    return 0

def fetch_json(url, ttl=30):
    r = http.get(url=url, ttl_seconds=ttl)
    if r.status_code != 200: return None
    b = r.body()
    if b == None or len(b) == 0 or b[0] != "{": return None
    return json.decode(b)

def logo_bytes(url):
    if url == "": return None
    r = http.get(url=url, ttl_seconds=36000)
    return r.body() if r.status_code == 200 else None

def team_meta(team):
    if type(team) != "dict": return {"code":"NFL","bg":"#202020","logo":""}
    code = s(team.get("abbreviation"), "NFL")
    col = s(team.get("color"), "")
    if col != "" and col[0] != "#": col = "#" + col
    if col == "" or col == "#000000" or col == "#ffffff": col = TEAM_BG.get(code, "#202020")
    return {"code":code, "bg":col, "logo":s(team.get("logo"), "")}

def record_text(competitor):
    if type(competitor) != "dict": return ""
    records = competitor.get("records")
    if type(records) != "list" or len(records) == 0: return ""
    for record in records:
        if type(record) == "dict" and s(record.get("summary"), "") != "": return s(record.get("summary"), "")
    return ""

def logo_node(meta, size):
    img = logo_bytes(meta["logo"])
    if img != None: return render.Image(img, width=size, height=size)
    return render.Text(meta["code"][0], font="6x13", color=WHITE)

def team_tile(meta, score, possession):
    logo = logo_node(meta, 16)
    dot = render.Box(width=3, height=3, color=WHITE) if possession else spacer_w(3)
    info = render.Box(width=13, height=16, child=render.Column(children=[
        spacer_h(1), render.Row(children=[render.Text(meta["code"], font="CG-pixel-3x5-mono", color=WHITE)], main_align="center", cross_align="center"),
        spacer_h(1), render.Row(children=[render.Text(str(score), font="5x8", color=WHITE)], main_align="center", cross_align="center"),
    ], main_align="start", cross_align="stretch"))
    return render.Box(color=meta["bg"], height=16, child=render.Row(children=[
        render.Box(width=16, height=16, child=render.Row(children=[logo], main_align="center", cross_align="center")), spacer_w(2), info, spacer_w(2), dot,
    ], main_align="start", cross_align="center"))

def pregame_team_tile(meta, record):
    logo = logo_node(meta, 16)
    record_node = spacer_w(15)
    if record != "":
        record_node = render.Box(width=15, height=16, child=render.Row(children=[render.Text(record, font="CG-pixel-3x5-mono", color=WHITE)], main_align="center", cross_align="center"))
    return render.Box(color=meta["bg"], width=36, height=16, child=render.Row(children=[
        render.Box(width=20, height=16, child=render.Row(children=[logo], main_align="center", cross_align="center")), spacer_w(1), record_node,
    ], main_align="start", cross_align="center"))

def left_panel(g):
    if g["state"] == "pre":
        return render.Box(width=36, child=render.Column(children=[pregame_team_tile(g["away"], g["away_record"]), pregame_team_tile(g["home"], g["home_record"])]))
    return render.Box(width=36, child=render.Column(children=[
        team_tile(g["away"], g["away_score"], g["possession"] == g["away"]["code"] and g["state"] == "live"),
        team_tile(g["home"], g["home_score"], g["possession"] == g["home"]["code"] and g["state"] == "live"),
    ]))

def centered_panel_text(text, font="5x8", color=WHITE):
    return render.Box(width=28, child=render.Row(children=[spacer_w(1), render.Box(width=27, child=render.Row(children=[render.Text(text, font=font, color=color)], main_align="center", cross_align="center"))], main_align="start", cross_align="center"))

def centered_panel_row(text, height, font, color):
    return render.Box(width=28, height=height, child=render.Row(children=[
        spacer_w(1),
        render.Box(width=27, height=height, child=render.Column(children=[
            render.Row(children=[render.Text(text, font=font, color=color)], main_align="center", cross_align="center"),
        ], main_align="center", cross_align="stretch")),
    ], main_align="start", cross_align="center"))

def preview_panel(g, config):
    date_color = s(config.get("pregame_date_color"), WHITE)
    time_color = s(config.get("pregame_time_color"), WHITE)
    return render.Box(width=28, height=32, child=render.Column(children=[
        centered_panel_row(g["date_text"], 16, "tom-thumb", date_color),
        centered_panel_row(g["clock_text"], 16, "5x8", time_color),
    ], main_align="start", cross_align="stretch"))

def live_panel(g, config):
    qc=s(config.get("quarter_color"),WHITE); tc=s(config.get("clock_color"),WHITE); dc=s(config.get("down_color"),WHITE); fc=s(config.get("field_color"),WHITE)
    return render.Box(width=28, height=32, child=render.Column(children=[
        spacer_h(1), centered_panel_text(g["quarter"], "CG-pixel-3x5-mono", qc), spacer_h(1), centered_panel_text(g["clock"], "5x8", tc),
        spacer_h(1), centered_panel_text(g["down_distance"], "CG-pixel-3x5-mono", dc), spacer_h(1), centered_panel_text(g["field_position"], "CG-pixel-3x5-mono", fc),
    ], main_align="start", cross_align="stretch"))

def final_panel(config):
    return render.Box(width=28, height=32, child=render.Column(children=[spacer_h(11), centered_panel_text("FINAL", "CG-pixel-3x5-mono", s(config.get("final_color"),WHITE))], cross_align="stretch"))

def render_game(g, config):
    right = preview_panel(g, config)
    if g["state"] == "live": right = live_panel(g, config)
    if g["state"] == "final": right = final_panel(config)
    return render.Box(color=BLACK, child=render.Row(children=[left_panel(g), right], main_align="start", cross_align="start"))

def parse_competition(event, timezone):
    comps = event.get("competitions") if type(event) == "dict" else None
    if type(comps) != "list" or len(comps) == 0: return None
    comp = comps[0]; competitors = comp.get("competitors")
    if type(competitors) != "list": return None
    away=None; home=None; away_score=0; home_score=0; away_record=""; home_record=""
    for c in competitors:
        if type(c) != "dict": continue
        m = team_meta(c.get("team"))
        if s(c.get("homeAway")) == "away": away=m; away_score=score_int(c.get("score")); away_record=record_text(c)
        if s(c.get("homeAway")) == "home": home=m; home_score=score_int(c.get("score")); home_record=record_text(c)
    if away == None or home == None: return None
    status=event.get("status"); stype=status.get("type") if type(status)=="dict" else {}
    state_raw=s(stype.get("state")) if type(stype)=="dict" else "pre"
    state="live" if state_raw=="in" else ("final" if state_raw=="post" else "pre")
    display_clock=s(status.get("displayClock"),"") if type(status)=="dict" else ""; period=i(status.get("period"),0) if type(status)=="dict" else 0
    quarter="Q"+str(period) if period>0 else ""
    situation=comp.get("situation"); possession=""; down_distance=""; field_position=""
    if type(situation)=="dict":
        possession=s(situation.get("possession"),""); down_distance=s(situation.get("shortDownDistanceText"),s(situation.get("downDistanceText"),"")); field_position=s(situation.get("possessionText"),"")
    date_raw=s(event.get("date"),""); date_text="TBD"; clock_text="TBD"
    if date_raw!="":
        parse_date=date_raw
        if len(date_raw)==17 and date_raw[16]=="Z": parse_date=date_raw[:16]+":00Z"
        t=time.parse_time(parse_date).in_location(timezone)
        date_text=t.format("Mon 1/2").upper()
        clock_text=t.format("3:04")
    return {"away":away,"home":home,"away_score":away_score,"home_score":home_score,"away_record":away_record,"home_record":home_record,"state":state,"quarter":quarter,"clock":display_clock,"possession":possession,"down_distance":down_distance,"field_position":field_position,"date_text":date_text,"clock_text":clock_text}

def get_games(config):
    data=fetch_json("https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?limit=100",30)
    if type(data)!="dict": return []
    events=data.get("events")
    if type(events)!="list": return []
    # Railway commonly runs in UTC. Do not inherit server timezone for user-facing NFL kickoff times.
    tz=s(config.get("timezone"),"America/New_York")
    games=[]
    for event in events:
        g=parse_competition(event,tz)
        if g!=None: games.append(g)
    return games

def selected_games(config):
    games=get_games(config); mode=s(config.get("mode"),"team")
    if mode=="all": return games
    team=s(config.get("team"),"PHI"); out=[]
    for g in games:
        if g["away"]["code"]==team or g["home"]["code"]==team: out.append(g)
    return out

def no_game():
    return render.Root(child=render.Box(color=BLACK,width=64,height=32,child=render.Column(children=[spacer_h(10),render.Box(width=64,child=render.Row(children=[render.Text("NO NFL GAME",font="5x8",color=WHITE)],main_align="center"))],cross_align="stretch")))

def main(config):
    games=selected_games(config)
    if len(games)==0: return no_game()
    frames=[]
    for g in games: frames.append(render_game(g,config))
    if len(frames)==1: return render.Root(child=frames[0])
    return render.Root(delay=8000,child=render.Animation(children=frames))

def get_schema():
    return schema.Schema(version="1",fields=[
        schema.Dropdown(id="mode",name="Game Mode",desc="Track one team or cycle all NFL games.",icon="gear",default="team",options=[schema.Option(display="Specific Team",value="team"),schema.Option(display="All Games",value="all")]),
        schema.Dropdown(id="team",name="Team Focus",desc="Team used in Specific Team mode.",icon="gear",default="PHI",options=teamOptions),
        schema.Color(id="pregame_date_color",name="Pregame Date Color",desc="Pregame date color.",icon="brush",default=WHITE), schema.Color(id="pregame_time_color",name="Pregame Time Color",desc="Pregame kickoff-time color.",icon="brush",default=WHITE),
        schema.Color(id="quarter_color",name="Quarter Color",desc="Live-game quarter color.",icon="brush",default=WHITE),
        schema.Color(id="clock_color",name="Clock Color",desc="Live-game clock color.",icon="brush",default=WHITE), schema.Color(id="down_color",name="Down & Distance Color",desc="Live-game down and distance color.",icon="brush",default=WHITE),
        schema.Color(id="field_color",name="Field Position Color",desc="Live-game field position color.",icon="brush",default=WHITE), schema.Color(id="final_color",name="Final Color",desc="Final-state text color.",icon="brush",default=WHITE),
    ])

teamOptions=[schema.Option(display=TEAM_NAMES[k],value=k) for k in TEAM_NAMES]

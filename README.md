# Voltway EV Charging

Voltway is a mobile-first, installable web app for finding charging stations and
booking a charging slot along a route. The frontend lives in `frontend/`; the
FastAPI and SQLite service lives in `app/`.

## Run locally

On Windows, double-click **`run_local.bat`**. It checks/installs the Python
dependencies, seeds the demo database if it does not exist, starts the API and
frontend, waits until both are responding, and opens the app in your browser.
It binds to all network interfaces, so another device on the same Wi-Fi can
also open the LAN address printed by the launcher. Allow Python through the
Windows Firewall for private networks if Windows asks.

To deliberately reset the demo station availability and bookings, run
`run_local.bat -Reseed`. To stop only the services launched for Voltway, run
`powershell -ExecutionPolicy Bypass -File .\stop_local.ps1`.

You can also start the services manually from the project root:

```powershell
python -m pip install -r requirements.txt
python seed.py
python -m uvicorn app.main:app --reload
```

Alternatively, open `frontend/mobile.html` with VS Code Live Server after
starting Uvicorn. The app uses the current web-page hostname on port 8000 for
its API by default, rather than assuming `127.0.0.1`; this works when opening
the app on the host computer or through its LAN address. To use an API on a
different host or port, open **Profile**, enter its origin under **Charging
service**, and save it. The API must be reachable from the device running the
app.

An assigned charger is reserved for 15 minutes. The app shows the time
remaining and lets the driver start charging or cancel the reservation. If the
timer expires, the server releases the slot automatically, even when the
driver has closed the page. A driver promoted from a station's queue receives
a fresh 15-minute reservation when the slot is assigned.

## Install on a phone

Serve the frontend and API over HTTPS, then open the frontend URL in the
phone's browser and choose **Add to Home Screen** or **Install app**. The
service worker caches the app shell; station data, map tiles, booking, and
charging still require an internet connection and a reachable API.

For phone testing on a local network, open the LAN address printed by
`run_local.bat`. If hosting the page separately, set **Profile → Charging
service** to `http://<computer-LAN-address>:8000`. Device geolocation and app
installation require a secure (HTTPS) origin in production.

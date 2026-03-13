import time
import hmac
import hashlib
import json
import os
import sys
import requests
import concurrent.futures
import threading

# ──────────────────────────────────────────────
# App Constants — must match the Android APK
# ──────────────────────────────────────────────
APP_VERSION  = "46"
APP_ID       = "xyz.indianx.app"
CLIENT_TYPE  = "Android"
OS_VERSION   = "30"
GAID         = "d802a45a-8b82-45a7-932f-abcdef123456"
ANDROID_ID   = "a1b2c3d4e5f6g7h8"
LANGUAGE     = "en"
BASE_URL     = "https://api.incoinpay.net"

# ──────────────────────────────────────────────
# Persistent session for connection pooling
# ──────────────────────────────────────────────
SESSION = requests.Session()
_adapter = requests.adapters.HTTPAdapter(
    pool_connections=100, pool_maxsize=100, max_retries=1
)
SESSION.mount('http://', _adapter)
SESSION.mount('https://', _adapter)

# ──────────────────────────────────────────────
# Core helpers
# ──────────────────────────────────────────────

def _get_app_keys():
    """Fetch the clientKey and clientSecret from the server."""
    url = f"{BASE_URL}/anon/client/checkVersion"
    headers = {
        "timestamp":  str(int(time.time() * 1000)),
        "version":    APP_VERSION,
        "OSVersion":  OS_VERSION,
        "clientKey":  "",
        "clientType": CLIENT_TYPE,
        "appId":      APP_ID,
        "language":   LANGUAGE,
        "gaid":       GAID,
        "androidId":  ANDROID_ID,
        "sign":       "",
    }
    try:
        resp = SESSION.get(url, headers=headers, timeout=10)
        data = resp.json()
        if data and data.get("data"):
            return data["data"]["clientKey"], data["data"]["clientSecret"]
    except Exception as e:
        pass
    return None, None


def _generate_sign(body_params, header_params, app_secret):
    """
    Sort all param values as strings, concat them, then HMAC-SHA1 with app_secret.
    This mirrors the exact logic used by the Android app.
    """
    all_params = {**body_params, **header_params}
    entries = [(str(k), v) for k, v in all_params.items()]
    entries.sort(key=lambda x: str(x[1]))

    sign_str = ""
    for k, v in entries:
        if isinstance(v, (str, int, float)):
            sign_str += str(v)

    hash_obj = hmac.new(
        app_secret.encode('utf-8'),
        sign_str.encode('utf-8'),
        hashlib.sha1
    )
    return hash_obj.hexdigest()


def _api_request(endpoint, body_params=None, app_key=None,
                  app_secret=None, token=None, method="POST"):
    """Makes a signed API request using the persistent session."""
    if body_params is None:
        body_params = {}

    timestamp = str(int(time.time() * 1000))
    header_params = {
        "timestamp":  timestamp,
        "version":    APP_VERSION,
        "OSVersion":  OS_VERSION,
        "clientKey":  app_key,
        "clientType": CLIENT_TYPE,
    }
    if token:
        header_params["token"] = token

    sign = _generate_sign(body_params, header_params, app_secret)

    final_headers = {
        **header_params,
        "appId":        APP_ID,
        "language":     LANGUAGE,
        "gaid":         GAID,
        "androidId":    ANDROID_ID,
        "sign":         sign,
        "Content-Type": "application/json",
    }

    url = f"{BASE_URL}{endpoint}"
    try:
        if method.upper() == "GET":
            resp = SESSION.get(url, params=body_params,
                               headers=final_headers, timeout=8)
        else:
            data = json.dumps(body_params).encode('utf-8')
            resp = SESSION.post(url, data=data,
                                headers=final_headers, timeout=8)
        return resp.json()
    except Exception:
        return None


def _get_captcha():
    """Fetch a captcha image and return (captchaToken, image_bytes)."""
    url = f"{BASE_URL}/anon/test/getCaptcha"
    try:
        resp = SESSION.get(url, timeout=8)
        captcha_token = resp.headers.get("captchaToken")
        if not captcha_token:
            return None, None
        return captcha_token, resp.content
    except Exception:
        return None, None


def _login_with_captcha(app_key, app_secret, username, password,
                         captcha_code="", captcha_token=""):
    """Attempt login. Returns token on success, None on failure."""
    body = {
        "userName":     username,
        "passwd":       password,
        "captcha":      captcha_code,
        "captchaToken": captcha_token,
    }
    res = _api_request("/anon/login", body, app_key, app_secret)
    if res and (res.get("code") == 0 or res.get("code") == "000000"):
        token = res.get("data", {}).get("token")
        if token:
            return token
    return None


def _select_tool(app_key, app_secret, token):
    """
    Fetch user's payment tools and return the best one.
    Prefers Freecharge; falls back to first available tool.
    """
    tools_res = _api_request("/api/tool/mylist", {},
                              app_key, app_secret, token, method="GET")
    if not tools_res or not tools_res.get("success"):
        return None, "Failed to fetch payment tools."

    tools = tools_res.get("data", [])
    if not tools:
        return None, "No payment tools found on account."

    for tool in tools:
        if tool.get('toolName', '').lower() == 'freecharge':
            return tool, None

    return tools[0], None   # fallback


def _execute_single_grab(order_id, app_key, app_secret, token, selected_tool):
    grab_payload = {
        "orderId":  order_id,
        "toolType": selected_tool.get('toolType'),
        "upiAddr":  selected_tool.get('upiAddr'),
    }
    res = _api_request("/api/order/grab", grab_payload,
                        app_key, app_secret, token, method="POST")
    return order_id, res


def _grab_and_confirm_orders(app_key, app_secret, token, selected_tool,
                              min_amount=101, max_amount=float('inf'),
                              target_count=3):
    """
    Poll for fresh orders matching the amount range, grab them concurrently,
    then confirm them.  Returns (success_count, log_lines[]).
    """
    logs = []
    grabbed_orders = []

    logs.append(f"Scanning for orders (₹{min_amount} – "
                 f"{'Any' if max_amount == float('inf') else max_amount})...")

    # ── Polling loop ──────────────────────────────────────────────────────
    max_poll_iterations = 300   # safety cap (~5 min at ~1 req/s)
    iteration = 0
    stop_flag = False

    while len(grabbed_orders) < target_count and not stop_flag:
        iteration += 1
        if iteration > max_poll_iterations:
            logs.append("Polling timeout reached. Stopping.")
            break

        page_payload = {"page": 1, "size": 30, "data": {}}
        list_res = _api_request("/api/order/grablist", page_payload,
                                 app_key, app_secret, token, method="POST")

        if not list_res or not list_res.get("success"):
            time.sleep(0.05)
            continue

        data    = list_res.get("data")
        records = []
        if isinstance(data, list):
            records = data
        elif isinstance(data, dict) and "records" in data:
            records = data.get("records", [])

        if not records:
            time.sleep(0.05)
            continue

        # Filter to orders that match amount range and haven't been grabbed yet
        orders_to_grab = []
        grabbed_ids    = {o['id'] for o in grabbed_orders}
        for order in records:
            order_id = order.get("orderId")
            amount   = order.get("amount", 0)
            if not order_id:
                continue
            if amount < min_amount or amount > max_amount:
                continue
            if order_id in grabbed_ids:
                continue
            orders_to_grab.append({"id": order_id, "amount": amount})
            if len(orders_to_grab) >= 10:   # cap concurrent grab burst
                break

        if not orders_to_grab:
            time.sleep(0.05)
            continue

        logs.append(f"Found {len(orders_to_grab)} matching order(s)! Grabbing and confirming...")

        # ── Concurrent grab & immediate confirmation ──────────────────
        def _grab_and_confirm(order_obj):
            oid, amt = order_obj['id'], order_obj['amount']
            grab_payload = {
                "orderId":  oid,
                "toolType": selected_tool.get('toolType'),
                "upiAddr":  selected_tool.get('upiAddr'),
            }
            res = _api_request("/api/order/grab", grab_payload,
                                app_key, app_secret, token, method="POST")
            
            if res and (res.get("code") == 0 or res.get("code") == "000000"):
                real_id = oid
                if isinstance(res.get("data"), dict) and res["data"].get("orderId"):
                    real_id = res["data"]["orderId"]
                
                # Confirm immediately
                confirm_payload = {"orderId": real_id}
                confirm_res = _api_request("/api/order/machine/review",
                                            confirm_payload, app_key, app_secret,
                                            token, method="POST")
                
                is_confirmed = confirm_res and (confirm_res.get("code") == 0 or confirm_res.get("code") == "000000")
                return {"id": real_id, "amount": amt, "grabbed": True, "confirmed": is_confirmed, "res": res}
            
            return {"id": oid, "amount": amt, "grabbed": False, "confirmed": False, "res": res}

        with concurrent.futures.ThreadPoolExecutor(max_workers=len(orders_to_grab)) as executor:
            futures = [executor.submit(_grab_and_confirm, o) for o in orders_to_grab]

            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                oid, amt = result['id'], result['amount']
                grab_res = result['res']

                if result['grabbed']:
                    logs.append(f"✓ Grabbed order {oid} (₹{amt})")
                    if result['confirmed']:
                        logs.append(f"  ✓ Confirmed!")
                        if oid not in {o['id'] for o in grabbed_orders}:
                            grabbed_orders.append({"id": oid, "amount": amt, "confirmed": True})
                    else:
                        logs.append(f"  ✗ Confirmation failed.")
                else:
                    msg = (grab_res.get('msg') if grab_res else 'Unknown error')
                    logs.append(f"✗ Missed {oid}: {msg}")
                    if msg and "reach max count" in msg.lower():
                        logs.append("Max grab count reached. Stopping.")
                        stop_flag = True

        confirmed_count = len([o for o in grabbed_orders if o.get('confirmed')])
        if confirmed_count >= target_count:
            break

    return confirmed_count, logs


# ══════════════════════════════════════════════
# PUBLIC API — called by Flutter via Chaquopy
# ══════════════════════════════════════════════

def start_order_grab(username: str, password: str,
                     min_amount: float = 101,
                     max_amount: float = float('inf'),
                     target_count: int = 3,
                     existing_token: str = "") -> str:
    """
    Entry point invoked by Android via Chaquopy MethodChannel.


    Parameters
    ----------
    username    : Incoin account username / phone
    password    : Incoin account password
    min_amount  : Minimum order amount to grab (default 101)
    max_amount  : Maximum order amount to grab (default unlimited)
    target_count: Number of orders to grab and confirm (default 3)

    Returns
    -------
    JSON string with keys: success (bool), message (str), logs (list[str])
    """
    result_logs = []

    try:
        # Step 1 – fetch app keys
        result_logs.append("Fetching app keys...")
        app_key, app_secret = _get_app_keys()
        if not app_key or not app_secret:
            return json.dumps({
                "success": False,
                "message": "Could not fetch app keys. Check internet connection.",
                "logs":    result_logs,
            })
        result_logs.append(f"App key obtained.")

        # Step 2 – login (try without captcha first; many accounts don't need it)
        if existing_token:
            result_logs.append("Using saved authentication token.")
            token = existing_token
        else:
            result_logs.append("Logging in...")
            captcha_token, captcha_bytes = _get_captcha()
            if not captcha_token:
                result_logs.append("Captcha fetch failed; attempting login without captcha...")
                captcha_token = ""

            token = _login_with_captcha(
                app_key, app_secret, username, password,
                captcha_code="",            # captcha is auto-skipped; server decides
                captcha_token=captcha_token or "",
            )
            if not token:
                return json.dumps({
                    "success": False,
                    "message": "Login failed. Please check your Incoin credentials.",
                    "logs":    result_logs,
                })
            result_logs.append("Login successful.")

        # Step 3 – select payment tool
        result_logs.append("Fetching payment tools...")
        selected_tool, tool_err = _select_tool(app_key, app_secret, token)
        if not selected_tool:
            return json.dumps({
                "success": False,
                "message": tool_err or "No payment tool available.",
                "logs":    result_logs,
            })
        result_logs.append(f"Using tool: {selected_tool.get('toolName')}")

        # Step 4 – grab & confirm orders
        success_count, grab_logs = _grab_and_confirm_orders(
            app_key, app_secret, token, selected_tool,
            min_amount=min_amount,
            max_amount=max_amount,
            target_count=target_count,
        )
        result_logs.extend(grab_logs)

        msg = (f"Done! Successfully confirmed {success_count}/{target_count} orders."
               if success_count > 0
               else "No orders were confirmed. The platform may have no orders right now.")

        return json.dumps({
            "success": success_count > 0,
            "message": msg,
            "logs":    result_logs,
            "confirmed": success_count,
        })

    except Exception as e:
        result_logs.append(f"Unexpected error: {str(e)}")
        return json.dumps({
            "success": False,
            "message": f"Script crashed: {str(e)}",
            "logs":    result_logs,
        })


# ══════════════════════════════════════════════
# Standalone CLI (for testing outside the app)
# ══════════════════════════════════════════════

def _load_users(users_file="users.json"):
    if os.path.exists(users_file):
        try:
            with open(users_file, 'r') as f:
                return json.load(f)
        except Exception:
            pass
    return []


def _save_users(users, users_file="users.json"):
    with open(users_file, 'w') as f:
        json.dump(users, f, indent=2)


def _cli_main():
    """Interactive CLI menu for running the script directly (testing only)."""
    min_amount = 101
    max_amount = float('inf')
    target_count = 3
    users = _load_users()

    while True:
        print("\n=== INCOIN ORDER GRABBER ===")
        print("1. Start Order Grab")
        print("2. Add User")
        print("3. Delete User")
        print(f"4. Set Amount Limits  (Current: ₹{min_amount} – "
              f"{'Any' if max_amount == float('inf') else max_amount})")
        print(f"5. Set Order Count    (Current: {target_count})")
        print("6. Exit")
        choice = input("Select an option: ").strip()

        if choice == "1":
            if not users:
                print("No users added yet. Please add a user first (option 2).")
                continue
            print("\n--- Select User ---")
            for idx, u in enumerate(users):
                print(f"  {idx + 1}. {u['username']}")
            try:
                sel = int(input("Select user by number: ").strip()) - 1
                if not (0 <= sel < len(users)):
                    print("Invalid selection.")
                    continue
                user = users[sel]
                print(f"\nStarting with user: {user['username']}")
                raw = start_order_grab(
                    user['username'], user['password'],
                    min_amount=min_amount,
                    max_amount=max_amount,
                    target_count=target_count,
                )
                result = json.loads(raw)
                print("\n--- RESULT ---")
                print(f"Status : {'SUCCESS' if result['success'] else 'FAILED'}")
                print(f"Message: {result['message']}")
                print("Logs:")
                for line in result.get("logs", []):
                    print(f"  {line}")
            except ValueError:
                print("Invalid input.")

        elif choice == "2":
            uname = input("Enter new username: ").strip()
            pwd   = input("Enter new password: ").strip()
            if uname and pwd:
                users.append({"username": uname, "password": pwd})
                _save_users(users)
                print(f"User '{uname}' added.")
            else:
                print("Username and password cannot be empty.")

        elif choice == "3":
            if not users:
                print("No users to delete.")
                continue
            print("\n--- Select User to Delete ---")
            for idx, u in enumerate(users):
                print(f"  {idx + 1}. {u['username']}")
            try:
                sel = int(input("Select user number: ").strip()) - 1
                if 0 <= sel < len(users):
                    deleted = users.pop(sel)
                    _save_users(users)
                    print(f"Deleted '{deleted['username']}'.")
                else:
                    print("Invalid selection.")
            except ValueError:
                print("Invalid input.")

        elif choice == "4":
            try:
                mn = input(f"Min amount (current: {min_amount}): ").strip()
                if mn:
                    min_amount = float(mn)
                mx = input(f"Max amount (current: {'Any' if max_amount == float('inf') else max_amount}, blank = no limit): ").strip()
                max_amount = float(mx) if mx else float('inf')
                print(f"Updated: ₹{min_amount} – {'Any' if max_amount == float('inf') else max_amount}")
            except ValueError:
                print("Invalid number.")

        elif choice == "5":
            try:
                tc = int(input(f"Target order count (current: {target_count}): ").strip())
                if tc > 0:
                    target_count = tc
                    print(f"Target count set to {target_count}.")
                else:
                    print("Must be greater than 0.")
            except ValueError:
                print("Invalid input.")

        elif choice == "6":
            print("Exiting.")
            sys.exit(0)

        else:
            print("Invalid option.")


if __name__ == "__main__":
    _cli_main()

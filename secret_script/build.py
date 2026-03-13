import os
import subprocess
import shutil

# Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT_NAME = "incoin_bot.py"
OBFUSCATED_DIR = os.path.join(BASE_DIR, "dist")
APP_PYTHON_DIR = os.path.join(BASE_DIR, "../incoin/android/app/src/main/python")

def run_command(command):
    print(f"Running: {command}")
    process = subprocess.run(command, shell=True, capture_output=True, text=True)
    if process.returncode != 0:
        print(f"Error executing command: {command}")
        print(process.stderr)
        exit(1)
    return process.stdout

def protect_script():
    print("Step 1: Obfuscating with PyArmor...")
    # NOTE: You must install pyarmor first: pip install pyarmor
    # We use pyarmor to obfuscate the script
    run_command(f"pyarmor gen {SCRIPT_NAME}")
    
    print("Step 2: Note about Cython")
    print("For full Cython integration in an Android project, Chaquopy actually supports compiling directly during the Gradle build process.")
    print("To keep this simple but secure, we will copy the obfuscated PyArmor output into the Chaquopy source directory.")
    
    # Ensure the destination directory exists
    os.makedirs(APP_PYTHON_DIR, exist_ok=True)
    
    # Copy the pyarmor output to the Android project
    protected_file = os.path.join(OBFUSCATED_DIR, SCRIPT_NAME)
    dest_file = os.path.join(APP_PYTHON_DIR, SCRIPT_NAME)
    
    if os.path.exists(protected_file):
        shutil.copy2(protected_file, dest_file)
        # Also need to copy the pyarmor_runtime directory
        runtime_src = os.path.join(OBFUSCATED_DIR, "pyarmor_runtime_000000")
        runtime_dest = os.path.join(APP_PYTHON_DIR, "pyarmor_runtime_000000")
        
        if os.path.exists(runtime_dest):
            shutil.rmtree(runtime_dest)
        
        if os.path.exists(runtime_src):
            shutil.copytree(runtime_src, runtime_dest)
            
        print(f"Success! Protected script copied to: {APP_PYTHON_DIR}")
    else:
        print("Error: PyArmor failed to generate the obfuscated script.")

if __name__ == "__main__":
    if not os.path.exists(os.path.join(BASE_DIR, SCRIPT_NAME)):
        print(f"Error: Could not find {SCRIPT_NAME} in {BASE_DIR}")
        print("Creating a dummy script for testing...")
        with open(os.path.join(BASE_DIR, SCRIPT_NAME), "w") as f:
            f.write("def start_order_grab(username, password):\n    return 'Successfully grabbed 3 orders for ' + username\n")
            
    protect_script()

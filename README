## SimpleRisk Configs
Enable "Control Number" filter in "Risk Management>Plan Mitigation".
Ensure all selection fields on data reflects real labels on system.

## Running script on linux terminals

Exporting the simplerisk password as environment variable:

```
set +o history
export SIMPLERISK_PASSWORD=your_actual_password
set -o history
```

Creating and activating the virtual environment:

```
python3 -m venv .venv
source .venv/bin/activate
```
Installing requirements and running the script:

```
pip install --upgrade pip
pip install -r requirements.txt
robot --outputdir results load_risks.robot
```

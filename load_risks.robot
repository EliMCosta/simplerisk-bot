*** Settings ***
Library    SeleniumLibrary
Library    OperatingSystem
Library    String
Library    Collections
Library    csv

*** Variables ***
${MAIN_URL}     https://localhost
${USERNAME}     admin
${CSV_FILE}     data.csv
${BROWSER}      headlesschrome
${TIMEOUT}      30s
${BROWSER_OPTIONS}    add_argument("--ignore-certificate-errors");add_argument("--ignore-ssl-errors")

*** Test Cases ***
Load Risks from CSV
    #Skip    msg=Skipped with Skip keyword.
    Verify CSV Content
    Open Browser and Login
    ${risks}=    Read CSV File
    FOR    ${risk}    IN    @{risks}
        Navigate to Risk Submission Page
        Fill Risk Form    ${risk}
        Submit Risk
    END
    [Teardown]    Close Browser

Add Mitigation Plans
    Open Browser and Login
    ${risks}=    Read CSV File
    FOR    ${risk}    IN    @{risks}
        Go To    ${MAIN_URL}/management/plan_mitigations.php
        Wait Until Page Contains    Plan Mitigation    timeout=${TIMEOUT}
        Verify Risk Exists    ${risk}[Control Number]
        Verify Risk Found After Filter    ${risk}[Control Number]
        Navigate to Mitigation Plan Page    ${risk}[Control Number]
        Fill Mitigation Plan    ${risk}
        Submit Mitigation Plan
        #Verify Mitigation Plan Saved    ${risk}
    END
    [Teardown]    Close Browser

*** Keywords ***
Verify CSV Content
    ${risks}=    Read CSV File
    FOR    ${risk}    IN    @{risks}
        Log    Risk details:
        FOR    ${key}    ${value}    IN    &{risk}
            Log    ${key}: ${value}
        END
    END

Read CSV File
    [Documentation]    Reads the CSV file and returns a list of dictionaries
    TRY
        ${risks}=    Create List
        ${file}=    Get File    ${CSV_FILE}    encoding=UTF-8
        @{lines}=    Split To Lines    ${file}
        ${headers}=    Remove From List    ${lines}    0
        @{header_list}=    Split String    ${headers}    ,
        ${csv_reader}=    Evaluate    csv.reader(${lines})
        FOR    ${row}    IN    @{csv_reader}
            ${risk_dict}=    Create Dictionary
            FOR    ${index}    ${header}    IN ENUMERATE    @{header_list}
                Set To Dictionary    ${risk_dict}    ${header}    ${row}[${index}]
            END
            Append To List    ${risks}    ${risk_dict}
        END
        RETURN    ${risks}
    EXCEPT    AS    ${error}
        Log    Failed to read CSV file: ${error}    level=ERROR
        Fatal Error    CSV file could not be read. Check file path and permissions.
    END

Open Browser and Login
    [Documentation]    Opens the browser and logs in to the application
    ${chrome_options}=    Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys, selenium.webdriver
    Call Method    ${chrome_options}    add_argument    --ignore-certificate-errors
    Call Method    ${chrome_options}    add_argument    --no-sandbox
    Call Method    ${chrome_options}    add_argument    --disable-dev-shm-usage
    
    ${PASSWORD}=    Get Environment Variable    SIMPLERISK_PASSWORD
    
    TRY
        Open Browser    ${MAIN_URL}    ${BROWSER}    options=${chrome_options}
        Maximize Browser Window
        Set Selenium Implicit Wait    ${TIMEOUT}
        Input Text      id=user    ${USERNAME}
        Input Password  id=pass    ${PASSWORD}
        Click Element   xpath=//button[contains(text(), 'Login')]
        Wait Until Page Contains    SimpleRisk    timeout=${TIMEOUT}
        Wait Until Element Is Visible    xpath=//*[@id="sidebarnav"]    timeout=${TIMEOUT}
        Log    Login successful
        Capture Page Screenshot    login_success.png
    EXCEPT    AS    ${error}
        Log    Failed to login: ${error}    level=ERROR
        Capture Page Screenshot    login_failure.png
        Fatal Error    Login failed. Check credentials and application status.
    END
Navigate to Risk Submission Page
    [Documentation]    Navigates to the risk submission page
    TRY
        Go To    ${MAIN_URL}/management/index.php
        Wait Until Element Is Visible    xpath=//*[@id="subject"]    timeout=${TIMEOUT}
        Sleep    1s
        Log    Navigation to risk submission page completed
        Capture Page Screenshot    risk_page_loaded.png
    EXCEPT    AS    ${error}
        Log    Failed to navigate to risk submission page: ${error}    level=ERROR
        Capture Page Screenshot    navigation_failure.png
        Fatal Error    Navigation to risk submission page failed.
    END

Fill Risk Form
    [Arguments]    ${risk}
    [Documentation]    Fills the risk form with provided data
    TRY
        Input Text    id=subject        ${risk}[Subject]
        Input Text    id=reference_id   ${risk}[External Reference ID]
        Select From List By Label    id=category    ${risk}[Category]
        Input Text    id=control_number    ${risk}[Control Number]
        Input Text    id=owner-selectized    ${risk}[Owner]
        Press Keys    id=owner-selectized    RETURN
        Select From List By Label    id=source    ${risk}[Risk Source]
        Select From List By Label    id=likelihood    ${risk}[Current Likelihood]
        Select From List By Label    id=impact    ${risk}[Current Impact]
        
        Fill TinyMCE Field    assessment_ifr    ${risk}[Risk Assessment]
        Fill TinyMCE Field    notes_ifr    ${risk}[Additional Notes]

        Log    Form filled successfully
        Capture Page Screenshot    form_filled.png
    EXCEPT    AS    ${error}
        Log    Failed to fill risk form: ${error}    level=ERROR
        Capture Page Screenshot    form_fill_failure.png
        Fatal Error    Form filling failed. Check field identifiers and data.
    END

Fill TinyMCE Field
    [Arguments]    ${iframe_id}    ${content}
    [Documentation]    Fills a TinyMCE field with provided content
    Wait Until Element Is Visible    id=${iframe_id}    timeout=${TIMEOUT}
    Select Frame    id=${iframe_id}
    Input Text    id=tinymce    ${content}
    ${actual_content}=    Get Text    xpath=//body
    Should Be Equal    ${actual_content}    ${content}    Content was not set correctly in TinyMCE field
    Unselect Frame

Submit Risk
    [Documentation]    Submits the risk form
    TRY
        Wait Until Element Is Visible    xpath=//*[@id="risk-submit-form"]/div[7]/div/div/div/button[1]    timeout=${TIMEOUT}
        Click Element    xpath=//*[@id="risk-submit-form"]/div[7]/div/div/div/button[1]
        Log    Risk submitted successfully
        Capture Page Screenshot    risk_submitted.png
    EXCEPT    AS    ${error}
        Log    Failed to submit risk: ${error}    level=ERROR
        Capture Page Screenshot    risk_submission_failure.png
        Fatal Error    Risk submission failed. Check form data and submission process.
    END

Navigate to Mitigation Plan Page
    [Arguments]    ${control_number}
    [Documentation]    Navigates to the mitigation plan page and filters by Control Number
    TRY
        Go To    ${MAIN_URL}/management/plan_mitigations.php
        Wait Until Element Is Visible    xpath=//input[@name='Control Number']    timeout=${TIMEOUT}
        Input Text    xpath=//input[@name='Control Number']    ${control_number}
        Press Keys    xpath=//input[@name='Control Number']    RETURN
        Log    Searching for risk with Control Number: ${control_number}
        Wait Until Page Contains Element    xpath=//table[@id='plan-mitigations']    timeout=${TIMEOUT}
        Capture Table Content    ${control_number}
        ${risk_id}=    Get Risk ID    ${control_number}
        Log    Found Risk ID: ${risk_id}
        ${mitigation_url}=    Set Variable    ${MAIN_URL}/management/view.php?id=${risk_id}&active=PlanYourMitigations#mitigation
        Go To    ${mitigation_url}
        Log    Navigated to: ${mitigation_url}
        Wait Until Element Is Visible    xpath=//*[@id="mitigation"]/form/div[1]/button    timeout=${TIMEOUT}
        Click Element    xpath=//*[@id="mitigation"]/form/div[1]/button
        Wait Until Element Is Visible    xpath=//input[@name='planning_date']    timeout=${TIMEOUT}
        Log    Navigated to mitigation plan page for risk ${risk_id}
        Capture Page Screenshot    mitigation_page_loaded.png
    EXCEPT    AS    ${error}
        Log    Failed to navigate to mitigation plan page: ${error}    level=ERROR
        Capture Page Screenshot    mitigation_navigation_failure.png
        Fatal Error    Navigation to mitigation plan page failed. Error: ${error}
    END

Get Risk ID
    [Arguments]    ${control_number}
    [Documentation]    Extracts the risk ID from the page
    Wait Until Element Is Visible    id=plan-mitigations_wrapper    timeout=${TIMEOUT}
    
    # Check if the control number is present in the table
    ${control_number_present}=    Run Keyword And Return Status    
    ...    Page Should Contain Element    xpath=//*[@id="plan-mitigations_wrapper"]//td[contains(text(), '${control_number}')]
    
    Run Keyword If    not ${control_number_present}    
    ...    Fatal Error    Control Number ${control_number} not found in the table
    
    ${risk_elements}=    Get WebElements    xpath=//*[@id="plan-mitigations_wrapper"]//div[@class='open-risk']
    
    ${risk_count}=    Get Length    ${risk_elements}
    Log    Number of risk elements found after general search: ${risk_count}
    
    Run Keyword If    ${risk_count} == 0    
    ...    Fatal Error    No risks found with Control Number ${control_number}
    
    Run Keyword If    ${risk_count} > 1    
    ...    Log    Warning: Multiple risks found with Control Number ${control_number}. Using the first one.    level=WARN
    
    ${risk_id}=    Get Element Attribute    ${risk_elements}[0]    data-id
    
    Run Keyword If    '${risk_id}' == 'None'    
    ...    Fatal Error    Could not find risk ID for Control Number ${control_number}
    
    Log    Found Risk ID: ${risk_id}
    RETURN    ${risk_id}

Fill Mitigation Plan
    [Arguments]    ${risk}
    [Documentation]    Fills the mitigation plan form with provided data
    TRY
        Input Text    xpath=//input[@name='planning_date']    ${risk}[Planned Mitigation Date]
        Select From List By Label    id=planning_strategy    ${risk}[Planning Strategy]
        Select From List By Label    id=mitigation_effort    ${risk}[Mitigation Effort]
        Select From List By Label    id=mitigation_owner    ${risk}[Mitigation Owner]
        
        Fill TinyMCE Field    current_solution_ifr    ${risk}[Current Solution]
        Fill TinyMCE Field    security_requirements_ifr    ${risk}[Security Requirements]
        
        # Verify TinyMCE fields content
        Verify TinyMCE Content    current_solution_ifr    ${risk}[Current Solution]
        Verify TinyMCE Content    security_requirements_ifr    ${risk}[Security Requirements]
        
        Sleep    1s
        Log    Mitigation plan form filled successfully
        Capture Page Screenshot    mitigation_form_filled.png
    EXCEPT    AS    ${error}
        Log    Failed to fill mitigation plan form: ${error}    level=ERROR
        Capture Page Screenshot    mitigation_form_fill_failure.png
        Fatal Error    Mitigation plan form filling failed. Check field identifiers and data.
    END

Verify TinyMCE Content
    [Arguments]    ${iframe_id}    ${expected_content}
    [Documentation]    Verifies the content of a TinyMCE field
    Select Frame    id=${iframe_id}
    ${actual_content}=    Get Text    xpath=//body
    Should Be Equal    ${actual_content}    ${expected_content}    Content in TinyMCE field does not match expected value
    Unselect Frame

Submit Mitigation Plan
    [Documentation]    Submits the mitigation plan form
    TRY
        # Scroll to the submit button to ensure it's in view
        Execute JavaScript    window.scrollTo(0, document.body.scrollHeight)
        
        # Wait for the button to be clickable
        Wait Until Element Is Visible    xpath=//*[@id="mitigation"]/form/div[1]/button[2]    timeout=${TIMEOUT}
        
        # Click the submit button
        Click Element    xpath=//*[@id="mitigation"]/form/div[1]/button[2]
        
        # Wait for the success message or a change in the page
        ${success}=    Run Keyword And Return Status    
        ...    Wait Until Page Contains    The Mitigation has been successfully modified.    timeout=${TIMEOUT}
        
        # If success message is not found, check for other indicators
        Run Keyword If    not ${success}    
        ...    Wait Until Element Is Not Visible    xpath=//*[@id="mitigation"]/form/div[1]/button[2]    timeout=${TIMEOUT}
        
        # Capture the state of the page after submission
        Capture Page Screenshot    mitigation_plan_after_submission.png
        
        # Log the result
        Run Keyword If    ${success}    Log    The Mitigation has been successfully modified.
        ...    ELSE    Log    Mitigation plan submission completed, but success message not found    level=WARN
        
    EXCEPT    AS    ${error}
        Log    Failed to submit mitigation plan: ${error}    level=ERROR
        Capture Page Screenshot    mitigation_plan_submission_failure.png
        Fatal Error    Mitigation plan submission failed. Error: ${error}
    END

Verify Risk Exists
    [Arguments]    ${control_number}
    [Documentation]    Verifies if the risk with the given Control Number exists
    Go To    ${MAIN_URL}/management/plan_mitigations.php
    Wait Until Element Is Visible    xpath=//input[@name='Control Number']    timeout=${TIMEOUT}
    Input Text    xpath=//input[@name='Control Number']    ${control_number}
    Press Keys    xpath=//input[@name='Control Number']    RETURN
    Sleep    1s
    ${risk_exists}=    Run Keyword And Return Status    Page Should Contain Element    xpath=//table[@id='plan-mitigations']//td[text()='${control_number}']
    Run Keyword If    not ${risk_exists}    Fatal Error    Risk with Control Number ${control_number} not found

Verify Risk Found After Filter
    [Arguments]    ${control_number}
    Wait Until Page Contains Element    xpath=//table[@id='plan-mitigations']    timeout=${TIMEOUT}
    Sleep    1s  # Add a small delay to ensure the table is fully loaded
    ${risk_exists}=    Run Keyword And Return Status    Page Should Contain Element    xpath=//table[@id='plan-mitigations']//td[text()='${control_number}']
    Run Keyword If    not ${risk_exists}    Capture Table Content    ${control_number}
    Run Keyword If    not ${risk_exists}    Fatal Error    Risk with Control Number ${control_number} not found after filtering

Capture Table Content
    [Arguments]    ${control_number}
    Wait Until Page Contains Element    xpath=//*[@id="plan-mitigations_wrapper"]    timeout=${TIMEOUT}
    ${table_content}=    Get Text    xpath=//*[@id="plan-mitigations_wrapper"]
    Log    Table content after filtering for ${control_number}:\n${table_content}
    Capture Page Screenshot    table_content_${control_number}.png

Verify Mitigation Plan Saved
    [Arguments]    ${risk}
    [Documentation]    Verifies if the mitigation plan was successfully saved
    Wait Until Page Contains    The Mitigation has been successfully modified.    timeout=${TIMEOUT}
    Reload Page
    Wait Until Element Is Visible    id=current_solution_ifr    timeout=${TIMEOUT}
    Verify TinyMCE Content    current_solution_ifr    ${risk}[Current Solution]
    Verify TinyMCE Content    security_requirements_ifr    ${risk}[Security Requirements]
    Log    Mitigation plan verified and saved successfully

Close Browser
    [Documentation]    Closes all open browsers
    Close All Browsers
    

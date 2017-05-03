require 'httparty'
require 'json'
require 'CGI'
require 'rubygems'
require 'pp'
require 'jira-ruby'
#globals
$pid = 10707
$teamid = 14302 #Modules team
$version_requirement = ">= 4.7.0 < 5.0.0"
$summary = "%s: Update the version compatibility to #{$version_requirement}" #prepend with module name
$epiclink = "TBD" #todo
$description = "Update the %s module version compatibility in the metadata.json to: \"version_requirement\": \"#{$version_requirement}\"\nThe current version_requirement is listed as \"%s\"\nSource: %s\nProject: %s\nSet issues_url to %s"
$issues_url_base = "https://tickets.puppetlabs.com/CreateIssueDetails!init.jspa?pid=10707&issuetype=1&team=Modules&customfield_14200=14302&labels=triage&customfield_10005=2147"

#helpers
def get_client()

    puts 'UserName:'
    username = gets.chomp
    puts 'Password:'
    password = gets.chomp

    options = {
                :username => username,
                :password => password,
                #:site     => 'http://127.0.0.1:2990', #local site
                #TODO change this when ready for prime time
                :site   => "https://jira1-test.ops.puppetlabs.net",
                :context_path => '',
                :auth_type => :basic,
                :ssl_verify_mode =>OpenSSL::SSL::VERIFY_NONE ,
                #:use_ssl => false, 
                :read_timeout => 120
            }

    client = JIRA::Client.new(options)
    return client  
end

def get_custom_issues_url(module_name)
    return $issues_url_base + "&summary=" + CGI.escape("Issue found with module: #{module_name}")
end

#Function declarations
def get_supported_modules()
    response = HTTParty.get("https://forgeapi.puppet.com/v3/modules?endorsements=supported&limit=1000&module_groups=base+pe_only")

    json = JSON.parse(response.body)
    
    return json
end

def list_projects_on_jira()
    

    client = get_client()

    # Show all projects
    projects = client.Project.all

    projects.each do |project|
    puts "Project -> key: #{project.key}, name: #{project.name}"
    end
end

def create_supported_module_update_tickets()
   supported_modules = get_supported_modules()
   client = get_client()
   supported_modules["results"].take(1).each do |child|
        issue = client.Issue.build
        requirements =  child["current_release"]["metadata"]["requirements"]
        source = child["current_release"]["metadata"]["source"]
        project_page = child["current_release"]["metadata"]["project_page"]
        version_requirement = "not listed"
        if requirements
            version_requirement =  requirements[0]["version_requirement"]
        end

        if version_requirement == $version_requirement
            return; #The version requirement has already been updated   
        end
        issue_json = { 
            "fields" => {
                #This call below doesn't work.  It has to be called out in a separate save
                #"customfield_10006"=> "MODULES-4694",
                "summary"=>"#{$summary}" % child["slug"],
                "description"=>"#{$description}" % [child["slug"], version_requirement, source, project_page, get_custom_issues_url(child["slug"])],
                "customfield_14200" =>{"id"=>"#{$teamid}"},
                "project"=>{"id"=>"#{$pid}"},
                "issuetype"=>{"id"=>"3"},
                "labels"=>["puppethack", "beginner"]
                
            }
        }
        issue.save(issue_json)
        
        issue.fetch
        #Separate call to save the custom field.  Adding it to the original json fails
        #TODO - change this when moving to production
        issue.save({"fields"=>{"customfield_10006"=>"MODULES-4694"}})
        pp issue.fields['summary']
    end
end

#Test Issue Creation
def create_test_issue()
    client = get_client()
    issue = client.Issue.build
    #issue.save({"fields"=>{"summary"=>"#{$summary}","description"=>"#{$description}","customfield_14200" =>{"id"=>"#{$teamid}"},"project"=>{"id"=>"#{$pid}"},"issuetype"=>{"id"=>"3"}}})
    issue_json = { 
        "fields" => {
            "summary"=>"#{$summary}" % child["slug"],
            "description"=>"#{$description}" % [child["slug"], child["current_release"]["metadata"]["requirements"]],
            "customfield_14200" =>{"id"=>"#{$teamid}"},
            "project"=>{"id"=>"#{$pid}"},
            "issuetype"=>{"id"=>"3"}
        }
    }
    issue.save(issue_json)
    issue.fetch
    pp issue.fields['summary']
end

def list_specific_issue()
    client = get_client()
    client.Issue.jql('key = "MODULES-4693"', {fields: %w(customfield_10006)}).each do |issue|
        #puts "#{issue.id} - #{issue.fields['summary']}"
        puts issue
    end
end

#This is where the work happens
#list_supported_modules()
#list_projects_on_jira()
#p "Creating test issue"
#create_test_issue()
#delete_all_issues()

create_supported_module_update_tickets()
#list_specific_issue()

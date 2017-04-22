
class SurveyDeploymentController < ApplicationController
  def action_allowed?
    ['Instructor',
     'Teaching Assistant',
     'Administrator'].include? current_role_name
  end

  def new
    @surveys = Questionnaire.where(type: 'CourseEvaluationQuestionnaire').map {|u| [u.name, u.id] }
    @course = Course.where(instructor_id: session[:user].id).map {|u| [u.name, u.id] }
    @total_students = CourseParticipant.where(parent_id: @course[0][1]).count
  end

  def param_test
    params.require(:survey_deployment).permit(:course_evaluation_id,:num_of_students,:start_date,:end_date,:validate_survey_deployment)

  end

  def create
    #survey_deployment = params[:survey_deployment]

    @survey_deployment = SurveyDeployment.new(param_test)
    if params[:random_subset]["value"] == "1"
      @survey_deployment.num_of_students = User.where(role_id: Role.student.id).length * rand
    end

    if @survey_deployment.save
      #add_participants(@survey_deployment.num_of_students, @survey_deployment.id)
      redirect_to action: 'list'
    else
      @surveys = Questionnaire.where(type: 'CourseEvaluationQuestionnaire').map {|u| [u.name, u.id] }
      @course = Course.where(instructor_id: session[:user].id).map {|u| [u.name, u.id] }
      @total_students = CourseParticipant.where(parent_id: @course[0][1]).count
      render(action: 'new')
    end
  end

  def list
    @survey_deployments = SurveyDeployment.all
    puts "SURVEY DEPLOYMENTS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts @survey_deployments
    @surveys = {}
    @survey_deployments.each do |sd|
      puts "Course eval id:" + sd.course_evaluation_id.to_s
      #@surveys[sd.id] = Questionnaire.find(sd.course_evaluation_id).name
      if(sd.course_evaluation_id.nil?)
        corresp_questionnaire_name = "Nil"
      else
        corresp_questionnaire_name = Questionnaire.find(sd.course_evaluation_id).name
      
      end
      #corresp_questionnaire_name = Questionnaire.find(sd.course_evaluation_id).name
      @surveys[sd.id] = corresp_questionnaire_name

    end
  end

  def delete
    SurveyDeployment.find(params[:id]).destroy
    SurveyParticipant.where(survey_deployment_id: params[:id]).each(&:destroy)
    SurveyResponse.where(survey_deployment_id: params[:id]).each(&:destroy)
    redirect_to action: 'list'
  end

  def add_participants(num_of_participants, survey_deployment_id) # Add participants
    users = User.where(role_id: Role.student.id)
    users_rand = users.sort_by { rand } # randomize user list
    num_of_participants.times do |i|
      survey_participant = SurveyParticipant.new
      survey_participant.user_id = users_rand[i].id
      survey_participant.survey_deployment_id = survey_deployment_id
      survey_participant.save
    end
  end

  def reminder_thread
    # Check status of  reminder thread
    @reminder_thread_status = "Running"
    unless MiddleMan.get_worker(session[:reminder_key])
      @reminder_thread_status = "Not Running"
    end
  end

  def toggle_reminder_thread
    # Create reminder thread using BackgroundRb or kill it if its already running
    if MiddleMan.get_worker(session[:reminder_key])
      MiddleMan.delete_worker(session[:reminder_key])
      session[:reminder_key] = nil
    else
      session[:reminder_key] = MiddleMan.new_worker class: :reminder_worker, args: {num_reminders: 3} # 3 reminders for now
    end
    redirect_to action: 'reminder_thread'
  end
end

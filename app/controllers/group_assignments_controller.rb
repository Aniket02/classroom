class GroupAssignmentsController < ApplicationController
  include OrganizationAuthorization

  before_action :set_group_assignment, except: [:new, :create]
  before_action :set_groupings,        except: [:show]

  decorates_assigned :organization

  rescue_from GitHub::Error, GitHub::Forbidden, GitHub::NotFound, with: :error

  def new
    @group_assignment = GroupAssignment.new
  end

  def create
    @group_assignment = GroupAssignment.new(new_group_assignment_params)

    if @group_assignment.save
      CreateGroupingJob.perform_later(@group_assignment, new_grouping_params)
      CreateGroupAssignmentInvitationJob.perform_later(@group_assignment)
      CreateGroupAssignmentReposJob.perform_later(@group_assignment.id)

      flash[:success] = "\"#{@group_assignment.title}\" has been created!"
      redirect_to organization_group_assignment_path(@organization, @group_assignment)
    else
      render :new
    end
  end

  def show
    @group_assignment_repos = @group_assignment.group_assignment_repos.page(params[:page])
  end

  private

  def error
    flash[:error] = exception.message
    redirect_to :back
  end

  def new_group_assignment_params
    params
      .require(:group_assignment)
      .permit(:title, :public_repo, :grouping_id)
      .merge(creator: current_user,
             organization: @organization,
             starter_code_repo_id: starter_code_repository_id(params[:repo_name]))
  end

  def new_grouping_params
    params
      .require(:grouping)
      .permit(:title)
      .merge(organization: @organization)
  end

  def set_groupings
    @groupings = @organization.groupings.map { |group| [group.title, group.id] }
  end

  def set_group_assignment
    @group_assignment = GroupAssignment.friendly.find(params[:id])
  end

  def starter_code_repository_id(repo_name)
    return unless repo_name.present?
    sanitized_repo_name = repo_name.gsub(/\s+/, '')
    github_repository   = GitHubRepository.new(current_user.github_client, nil)
    github_repository.repository(sanitized_repo_name).id
  end
end

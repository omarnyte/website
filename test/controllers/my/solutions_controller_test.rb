require 'test_helper'

class SolutionsControllerTest < ActionDispatch::IntegrationTest

  def setup
    @mock_exercise = stub(
      instructions: "instructions",
      test_suite: { "test_file" => "test_suite" },
      files: [],
      about_present: false
    )

    @mock_repo = stub(exercise: @mock_exercise)
    Git::Exercise.stubs(new: @mock_exercise)
    Git::ExercismRepo.stubs(new: @mock_repo)
    Git::ExercismRepo::PAGES.each do |page|
      @mock_repo.stubs("#{page}_present?", false)
    end
  end

  {
    unlocked: "my-solution-unlocked-page",
    iterating: "my-solution-page",
    completed_unapproved: "my-solution-page",
    completed_approved: "my-solution-page",
  }.each do |status, page|
    test "shows with status #{status}" do
      sign_in!
      solution = send("create_#{status}_solution")
      solution.exercise.track.stubs(repo: @mock_repo)
      create :user_track, user: @current_user, track: solution.exercise.track

      get my_solution_url(solution)
      assert_response :success
      assert_correct_page page
    end
  end

  test "reflects properly" do
    sign_in!
    track = create :track
    user_track = create :user_track, track: track, user: @current_user

    exercise = create :exercise, core: true, track: track
    solution = create :solution, user: @current_user, exercise: exercise
    iteration = create :iteration, solution: solution
    discussion_post_1 = create :discussion_post, iteration: iteration
    discussion_post_2 = create :discussion_post, iteration: iteration
    discussion_post_3 = create :discussion_post, iteration: iteration
    reflection = "foobar"

    create :solution_mentorship, solution: solution, user: discussion_post_1.user
    create :solution_mentorship, solution: solution, user: discussion_post_3.user

    # Create next core exercise for user
    next_exercise = create :exercise, track: exercise.track, position: 2, core: true
    create :solution, user: @current_user, exercise: next_exercise

    patch reflect_my_solution_url(solution), params: {
      reflection: reflection,
      mentor_reviews: {
        discussion_post_1.user_id => { rating: 3, review: "asdasd" },
        discussion_post_3.user_id => { rating: 2, review: "asdaqweqwewqewq" }
      }
    }

    assert_response :success

    solution.reload
    assert_equal solution.reflection, reflection
    assert_equal 2, SolutionMentorship.where.not(rating: nil).count
  end

  test "migrates to v2 properly" do
    sign_in!
    solution = create :solution,
                      user: @current_user,
                      completed_at: Time.now - 1.week,
                      published_at: Time.now - 1.week,
                      approved_by: create(:user),
                      last_updated_by_user_at: Time.now - 1.week,
                      updated_at: Time.now - 1.week

    patch migrate_to_v2_my_solution_url(solution.uuid)
    assert_redirected_to my_solution_url(solution.uuid)

    solution.reload
    assert_nil solution.completed_at
    assert_nil solution.published_at
    assert_nil solution.approved_by
    assert_equal Time.now.to_i, solution.last_updated_by_user_at.to_i
    assert_equal Time.now.to_i, solution.updated_at.to_i
  end

  test "reflects without next core exercise" do
    skip
  end

  def create_unlocked_solution
    create :solution, user: @current_user
  end

  def create_iterating_solution
    solution = create :solution, user: @current_user
    iteration = create :iteration, solution: solution
    solution
  end

  def create_completed_unapproved_solution
    solution = create :solution, user: @current_user, completed_at: Date.yesterday
    iteration = create :iteration, solution: solution
    solution
  end

  def create_completed_approved_solution
    solution = create :solution, user: @current_user, completed_at: Date.yesterday, approved_by: create(:user)
    iteration = create :iteration, solution: solution
    solution
  end
end

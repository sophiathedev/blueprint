# frozen_string_literal: true

module Admin
  class TasksController < BaseController
    before_action :set_partner
    before_action :set_service
    before_action :set_task, only: %i[update destroy]

    def index
      @query = params[:q].to_s.strip
      load_assignable_members
      load_tasks
      @task = @service.tasks.build
    end

    def new
      @order_task_name = @service.name
    end

    def create
      @task = @service.tasks.build(task_params)

      if @task.save
        respond_to do |format|
          format.html { redirect_to admin_partner_service_tasks_path(@partner, @service), notice: 'Tạo task thành công.' }
          format.turbo_stream do
            @query = params[:q].to_s.strip
            load_assignable_members
            load_tasks
            @task = @service.tasks.build
            flash.now[:notice] = 'Tạo task thành công.'
            render_tasks_turbo_stream
          end
        end
      else
        load_assignable_members
        load_tasks
        @open_task_modal = true
        flash.now[:alert] = @task.errors.full_messages

        respond_to do |format|
          format.html { render :index, status: :unprocessable_entity }
          format.turbo_stream { render_flash_turbo_stream(status: :unprocessable_entity) }
        end
      end
    end

    def update
      if @task.update(task_params)
        return render_inline_tasks_panel if turbo_frame_request?

        respond_to do |format|
          format.html { redirect_to admin_partner_service_tasks_path(@partner, @service), notice: 'Cập nhật task thành công.' }
          format.turbo_stream do
            @query = params[:q].to_s.strip
            load_assignable_members
            load_tasks
            @task = @service.tasks.build
            flash.now[:notice] = 'Cập nhật task thành công.'
            render_tasks_turbo_stream
          end
        end
      else
        return render_inline_tasks_panel(status: :unprocessable_entity, edit_task: @task) if turbo_frame_request?

        respond_to do |format|
          format.html { redirect_to admin_partner_service_tasks_path(@partner, @service), alert: @task.errors.full_messages }
          format.turbo_stream do
            error_message = @task.errors.full_messages
            @query = params[:q].to_s.strip
            load_assignable_members
            load_tasks
            @task = @service.tasks.build
            flash.now[:alert] = error_message
            render_tasks_turbo_stream(status: :unprocessable_entity)
          end
        end
      end
    end

    def destroy
      @task.destroy
      return render_inline_tasks_panel if turbo_frame_request?

      redirect_to admin_partner_service_tasks_path(@partner, @service), notice: 'Xóa task thành công.'
    end

    private

    def set_partner
      @partner = Partner.find(params[:partner_id])
    end

    def set_service
      @service = @partner.services.find(params[:service_id])
    end

    def set_task
      @task = @service.tasks.find(params[:id])
    end

    def load_tasks
      @tasks = @service.tasks.includes(:member).order(:name, :id)
      return if @query.blank?

      @tasks = @tasks.where('name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
    end

    def task_params
      params.expect(task: %i[name member_id])
    end

    def load_assignable_members
      @member_options = User.member.order(created_at: :desc, id: :desc).map do |member|
        [ member.display_name, member.id ]
      end
      @inline_member_options = @member_options
    end

    def render_tasks_turbo_stream(status: :ok)
      render turbo_stream: [
        turbo_stream.replace(
          'tasks_list_section',
          partial: 'admin/tasks/tasks_list',
          locals: { tasks: @tasks }
        ),
        turbo_stream.prepend(
          'flash_messages',
          partial: 'shared/flash_messages',
          locals: { flash: flash }
        )
      ], status: status
    end

    def render_flash_turbo_stream(status: :ok)
      render turbo_stream: turbo_stream.prepend(
        'flash_messages',
        partial: 'shared/flash_messages',
        locals: { flash: flash }
      ), status: status
    end

    def render_inline_tasks_panel(status: :ok, edit_task: nil)
      load_assignable_members
      @tasks = @service.tasks.includes(:member).order(:name, :id)
      show_all_tasks = ActiveModel::Type::Boolean.new.cast(params[:show_all])

      render partial: 'admin/services/tasks_panel', locals: {
        partner: @partner,
        service: @service,
        tasks: @tasks,
        member_options: @member_options,
        edit_task: edit_task,
        show_all_tasks: show_all_tasks
      }, status: status
    end

  end
end

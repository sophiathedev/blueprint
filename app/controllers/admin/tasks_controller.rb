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
      build_order_service_form
    end

    def create
      return create_order_service if order_request_submission?

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

    def order_request_submission?
      params[:order_request].present?
    end

    def create_order_service
      @order_service = @service.order_services.build(order_service_attributes)

      if @order_service.save
        redirect_to root_path, notice: 'Đặt dịch vụ thành công.'
      else
        flash.now[:alert] = order_service_error_messages
        render :new, status: :unprocessable_entity
      end
    end

    def build_order_service_form
      @order_service = @service.order_services.build
      @order_request_data = default_order_request_data
    end

    def order_service_attributes
      @order_request_data = normalized_order_request_data

      {
        completed_at: build_completed_at(@order_request_data),
        partner_assignee_name: @order_request_data[:partner_assignee_name],
        priority_status: @order_request_data[:priority_status],
        notes: @order_request_data[:detailed_notes]
      }
    end

    def order_request_params
      params.expect(order_request: %i[
        completion_date
        completion_date_enabled
        completion_time_enabled
        completion_hour
        completion_minute
        partner_assignee_name
        priority_status
        detailed_notes
      ])
    end

    def normalized_order_request_data
      request_params = order_request_params
      completion_date = request_params[:completion_date].to_s
      completion_time_enabled = ActiveModel::Type::Boolean.new.cast(request_params[:completion_time_enabled])

      default_order_request_data.merge(
        completion_date: completion_date,
        completion_date_enabled: request_params[:completion_date_enabled].presence || (completion_date.present? ? '1' : '0'),
        completion_time_enabled: completion_time_enabled ? '1' : '0',
        completion_hour: completion_time_enabled ? normalized_time_part(request_params[:completion_hour]) : '',
        completion_minute: completion_time_enabled ? normalized_time_part(request_params[:completion_minute]) : '',
        partner_assignee_name: request_params[:partner_assignee_name].to_s,
        priority_status: request_params[:priority_status].to_s,
        detailed_notes: request_params[:detailed_notes].to_s
      )
    end

    def build_completed_at(order_request_data)
      completion_date = order_request_data[:completion_date]
      return if completion_date.blank?

      return completion_date unless order_request_data[:completion_time_enabled] == '1'

      "#{completion_date} #{order_request_data[:completion_hour]}:#{order_request_data[:completion_minute]}"
    end

    def normalized_time_part(value)
      format('%02d', value.to_i)
    end

    def default_order_request_data
      {
        completion_date: '',
        completion_date_enabled: '1',
        completion_time_enabled: '0',
        completion_hour: '',
        completion_minute: '',
        partner_assignee_name: '',
        priority_status: 'medium',
        detailed_notes: ''
      }
    end

    def order_service_error_messages
      @order_service.errors.map do |error|
        next 'Vui lòng chọn thời gian hoàn thành.' if error.attribute == :completed_at && error.type == :blank
        next 'Vui lòng chọn thời gian hoàn thành từ hiện tại trở đi.' if error.attribute == :completed_at && error.type == :invalid
        next 'Vui lòng chọn thời gian hoàn thành từ hiện tại trở đi.' if error.attribute == :completed_at && error.message == 'phải từ thời điểm hiện tại trở đi'

        "#{order_service_attribute_label(error.attribute)} #{error.message}"
      end.uniq
    end

    def order_service_attribute_label(attribute)
      case attribute.to_sym
      when :partner_assignee_name
        'Tên nhân sự của đối tác'
      when :priority_status
        'Trạng thái ưu tiên'
      when :completed_at
        'Thời gian hoàn thành'
      else
        OrderService.human_attribute_name(attribute)
      end
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

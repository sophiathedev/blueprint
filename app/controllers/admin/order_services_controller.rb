# frozen_string_literal: true

module Admin
  class OrderServicesController < BaseController
    skip_before_action :require_admin, only: :show
    before_action :set_order_service, only: %i[show edit update]
    before_action :set_order_tasks, only: :show
    before_action :load_service_selection_options, only: %i[new create]

    def new
      @selected_service = Service.includes(:partner).find_by(id: params[:service_id])
      @partner = @selected_service&.partner
      @order_service = @selected_service ? @selected_service.order_services.build : OrderService.new
      @order_request_data = default_order_request_data.merge(
        service_id: @selected_service&.id.to_s,
        partner_name: @partner&.name.to_s
      )
    end

    def create
      @order_request_data = normalized_order_request_data
      @selected_service = Service.includes(:partner).find_by(id: @order_request_data[:service_id])
      @partner = @selected_service&.partner
      @order_service = OrderService.new(order_service_attributes_from(@order_request_data))
      @order_service.service = @selected_service if @selected_service.present?

      if @order_service.save
        redirect_to root_path, notice: 'Đặt dịch vụ thành công.'
      else
        flash.now[:alert] = order_service_error_messages
        render :new, status: :unprocessable_entity
      end
    end

    def show; end

    def service_options
      query = params[:q].to_s.strip
      services = Service
        .includes(:partner)
        .references(:partner)
        .order('partners.name ASC', 'services.name ASC', 'services.id ASC')
      if query.present?
        sanitized_query = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        services = services.where('services.name ILIKE :query OR partners.name ILIKE :query', query: sanitized_query)
      end

      render json: services.limit(50).map { |service| service_option_for(service) }
    end

    def edit
      @order_request_data = order_request_data_from(@order_service)
    end

    def update
      @order_request_data = normalized_order_request_data

      if @order_service.update(order_service_attributes_from(@order_request_data))
        redirect_to admin_order_service_path(@order_service), notice: 'Cập nhật order thành công.'
      else
        flash.now[:alert] = order_service_error_messages
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_order_service
      @order_service = visible_order_services_scope.includes(service: :partner).find(params[:id])
      @service = @order_service.service
      @partner = @service.partner
    end

    def set_order_tasks
      @order_tasks = @order_service.order_tasks.visible_to(current_user).includes(task: :member).sort_by do |order_task|
        [order_task.is_completed? ? 1 : 0, order_task.task.name]
      end
      @highlight_current_user_tasks = params[:source] == 'dashboard'
    end

    def visible_order_services_scope
      scope = OrderService.all
      return scope if current_user.admin?

      scope.where(id: OrderTask.for_user_order_services(current_user))
    end

    def order_service_form_params
      params.expect(order_service: %i[
        service_id
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
      request_params = order_service_form_params
      completion_date = request_params[:completion_date].to_s
      completion_time_enabled = ActiveModel::Type::Boolean.new.cast(request_params[:completion_time_enabled])

      {
        service_id: request_params[:service_id].to_s,
        partner_name: service_partner_name_from(request_params[:service_id]),
        completion_date: completion_date,
        completion_date_enabled: request_params[:completion_date_enabled].presence || (completion_date.present? ? '1' : '0'),
        completion_time_enabled: completion_time_enabled ? '1' : '0',
        completion_hour: completion_time_enabled ? normalized_time_part(request_params[:completion_hour]) : '',
        completion_minute: completion_time_enabled ? normalized_time_part(request_params[:completion_minute]) : '',
        partner_assignee_name: request_params[:partner_assignee_name].to_s,
        priority_status: request_params[:priority_status].to_s,
        detailed_notes: request_params[:detailed_notes].to_s
      }
    end

    def order_request_data_from(order_service)
      {
        service_id: order_service.service_id.to_s,
        partner_name: order_service.service.partner.name.to_s,
        completion_date: order_service.completed_at&.strftime('%Y-%m-%d').to_s,
        completion_date_enabled: '1',
        completion_time_enabled: '1',
        completion_hour: order_service.completed_at&.strftime('%H').to_s,
        completion_minute: order_service.completed_at&.strftime('%M').to_s,
        partner_assignee_name: order_service.partner_assignee_name.to_s,
        priority_status: order_service.priority_status.to_s,
        detailed_notes: order_service.notes.to_s
      }
    end

    def order_service_attributes_from(order_request_data)
      {
        completed_at: build_completed_at(order_request_data),
        partner_assignee_name: order_request_data[:partner_assignee_name],
        priority_status: order_request_data[:priority_status],
        notes: order_request_data[:detailed_notes]
      }
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
        service_id: '',
        partner_name: '',
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
        next 'Vui lòng chọn dịch vụ.' if error.attribute == :service
        next 'Vui lòng chọn thời gian hoàn thành.' if error.attribute == :completed_at && error.type == :blank
        next 'Vui lòng chọn thời gian hoàn thành từ hiện tại trở đi.' if error.attribute == :completed_at && error.type == :invalid
        next 'Vui lòng chọn thời gian hoàn thành từ hiện tại trở đi.' if error.attribute == :completed_at && error.message == 'phải từ thời điểm hiện tại trở đi'

        "#{order_service_attribute_label(error.attribute)} #{error.message}"
      end.uniq
    end

    def order_service_attribute_label(attribute)
      case attribute.to_sym
      when :service
        'Dịch vụ'
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

    def load_service_selection_options
      @service_options = [
        { label: 'Chọn dịch vụ cần đặt', value: '', data: { partner_name: '' } }
      ]
    end

    def service_partner_name_from(service_id)
      return '' if service_id.blank?

      Service.includes(:partner).find_by(id: service_id)&.partner&.name.to_s
    end

    def service_option_for(service)
      {
        label: "#{service.name} • #{service.partner.name}",
        value: service.id.to_s,
        data: { partner_name: service.partner.name }
      }
    end
  end
end

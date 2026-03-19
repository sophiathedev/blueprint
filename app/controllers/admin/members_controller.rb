# frozen_string_literal: true

module Admin
  class MembersController < BaseController
    before_action :set_member, only: %i[update destroy reset_password]

    def index
      load_members
      @new_member = build_member
      prepare_member_modals
      @credentials_modal = credentials_modal_payload
    end

    def create
      generated_password = User.generate_strong_password
      @new_member = build_member(member_create_params).tap do |member|
        member.password = generated_password
        member.password_confirmation = generated_password
      end

      if @new_member.save
        credentials_payload = credentials_payload_for(
          member: @new_member,
          password: generated_password,
          title: 'Thông tin đăng nhập đã được tạo',
          description: 'Hệ thống đã sinh mật khẩu mạnh cho tài khoản mới. Hãy lưu lại trước khi đóng modal.'
        )

        respond_to do |format|
          format.html do
            redirect_to admin_members_path,
                        notice: 'Tạo người dùng thành công.',
                        flash: { member_credentials: credentials_payload }
          end

          format.turbo_stream do
            load_members
            @new_member = build_member
            @credentials_modal = credentials_payload
            flash.now[:notice] = 'Tạo người dùng thành công.'
            render_members_turbo_stream
          end
        end
      else
        load_members
        @open_create_modal = true
        flash.now[:alert] = @new_member.errors.full_messages
        render_members_response(status: :unprocessable_entity, replace_page: false)
      end
    end

    def update
      if @member.update(member_update_params)
        respond_to do |format|
          format.html { redirect_to admin_members_path, notice: 'Cập nhật người dùng thành công.' }
          format.turbo_stream do
            load_members
            @new_member = build_member
            flash.now[:notice] = 'Cập nhật người dùng thành công.'
            render_members_turbo_stream
          end
        end
      else
        load_members
        @new_member = build_member
        @edit_member = @member
        @open_edit_member_id = @member.id
        flash.now[:alert] = @member.errors.full_messages
        render_members_response(status: :unprocessable_entity, replace_page: false)
      end
    end

    def destroy
      if @member == current_user
        respond_to do |format|
          format.html { redirect_to admin_members_path, alert: 'Bạn không thể tự xóa chính mình.' }
          format.turbo_stream do
            load_members
            @new_member = build_member
            flash.now[:alert] = 'Bạn không thể tự xóa chính mình.'
            render_members_turbo_stream(status: :unprocessable_entity)
          end
        end
        return
      end

      @member.destroy
      respond_to do |format|
        format.html { redirect_to admin_members_path, notice: 'Xóa người dùng thành công.' }
        format.turbo_stream do
          load_members
          @new_member = build_member
          flash.now[:notice] = 'Xóa người dùng thành công.'
          render_members_turbo_stream
        end
      end
    end

    def reset_password
      if @member.update(password_reset_params)
        respond_to do |format|
          format.html { redirect_to admin_members_path, notice: 'Đổi mật khẩu người dùng thành công.' }
          format.turbo_stream do
            load_members
            @new_member = build_member
            flash.now[:notice] = 'Đổi mật khẩu người dùng thành công.'
            render_members_turbo_stream
          end
        end
      else
        load_members
        @new_member = build_member
        @password_member = @member
        @open_reset_password_member_id = @member.id
        flash.now[:alert] = @member.errors.full_messages
        render_members_response(status: :unprocessable_entity, replace_page: false)
      end
    end

    private

    def set_member
      @member = User.find(params[:id])
    end

    def load_members
      @members = User.order(:id)
      return if params[:q].to_s.strip.blank?

      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @members = @members.where('name ILIKE ? OR email ILIKE ?', query, query)
    end

    def build_member(attributes = {})
      User.new({ role: :member }.merge(attributes.to_h.symbolize_keys))
    end

    def member_create_params
      params.expect(user: %i[name email])
    end

    def member_update_params
      params.expect(user: %i[name email role])
    end

    def password_reset_params
      params.expect(user: %i[password password_confirmation])
    end

    def credentials_modal_payload
      payload = flash[:member_credentials]
      return if payload.blank?

      payload.to_h.deep_symbolize_keys
    end

    def prepare_member_modals
      return if @open_edit_member_id.present?

      if params[:edit_member_id].present?
        @edit_member = User.find_by(id: params[:edit_member_id])
        @open_edit_member_id = @edit_member&.id
      end

      return unless params[:reset_password_member_id].present?

      @password_member = User.find_by(id: params[:reset_password_member_id])
      @open_reset_password_member_id = @password_member&.id
    end

    def credentials_payload_for(member:, password:, title:, description:)
      {
        title: title,
        description: description,
        name: member.name,
        email: member.email,
        password: password
      }
    end

    def render_members_response(status:, replace_page: true)
      respond_to do |format|
        format.html { render :index, status: status }
        format.turbo_stream do
          if replace_page
            render_members_turbo_stream(status: status)
          else
            render_flash_turbo_stream(status: status)
          end
        end
      end
    end

    def render_members_turbo_stream(status: :ok)
      render turbo_stream: [
        turbo_stream.replace(
          'admin_members_page',
          partial: 'admin/members/page'
        ),
        turbo_stream.update(
          'flash_container',
          partial: 'shared/flash',
          locals: { flash: flash }
        )
      ], status: status
    end

    def render_flash_turbo_stream(status: :ok)
      render turbo_stream: turbo_stream.update(
        'flash_container',
        partial: 'shared/flash',
        locals: { flash: flash }
      ), status: status
    end
  end
end

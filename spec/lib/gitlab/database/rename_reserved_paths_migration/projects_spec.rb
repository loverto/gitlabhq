require 'spec_helper'

describe Gitlab::Database::RenameReservedPathsMigration::Projects, :truncate do
  let(:subject) do
    ActiveRecord::Migration.new.extend(
      Gitlab::Database::RenameReservedPathsMigration
    )
  end

  before do
    allow(subject).to receive(:say)
  end

  describe '#projects_for_paths' do
    it 'includes the correct projects' do
      project = create(:empty_project, path: 'THE-path')
      _other_project = create(:empty_project)

      result_ids = subject.projects_for_paths(['the-PATH']).map(&:id)

      expect(result_ids).to contain_exactly(project.id)
    end
  end

  describe '#rename_project' do
    let(:project) do
      create(:empty_project,
             path: 'the-path',
             namespace: create(:namespace, path: 'known-parent' ))
    end

    it 'renames path & route for the project' do
      expect(subject).to receive(:rename_path_for_routable).
                           with(project).
                           and_call_original

      subject.rename_project(project)
    end

    it 'moves the wiki & the repo' do
      expect(subject).to receive(:move_repository).
                           with(project, 'known-parent/the-path.wiki', 'known-parent/the-path0.wiki')
      expect(subject).to receive(:move_repository).
                           with(project, 'known-parent/the-path', 'known-parent/the-path0')

      subject.rename_project(project)
    end

    it 'moves uploads' do
      expect(subject).to receive(:move_uploads).
                           with('known-parent/the-path', 'known-parent/the-path0')

      subject.rename_project(project)
    end

    it 'moves pages' do
      expect(subject).to receive(:move_pages).
                           with('known-parent/the-path', 'known-parent/the-path0')

      subject.rename_project(project)
    end

    it 'invalidates the markdown cache of related projects'
  end

  describe '#move_repository' do
    let(:known_parent) { create(:namespace, path: 'known-parent') }
    let(:project) { create(:project, path: 'the-path', namespace: known_parent) }

    it 'moves the repository for a project' do
      expected_path = File.join(TestEnv.repos_path, 'known-parent', 'new-repo.git')

      subject.move_repository(project, 'known-parent/the-path', 'known-parent/new-repo')

      expect(File.directory?(expected_path)).to be(true)
    end
  end
end

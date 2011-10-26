require 'spec_helper'

describe RspecApiDocumentation::ApiDocumentation do
  let(:format) { :html }
  let(:configuration) { RspecApiDocumentation::Configuration.new(format) }
  let(:documentation) { RspecApiDocumentation::ApiDocumentation.new(configuration) }

  subject { documentation }

  its(:configuration) { should equal(configuration) }
  its(:private_index) { should be_a(RspecApiDocumentation::Index) }
  its(:public_index) { should be_a(RspecApiDocumentation::Index) }
  its(:examples) { should be_empty }

  describe "#clear_docs" do
    include FakeFS::SpecHelpers

    it "should rebuild the docs directory" do
      test_file = configuration.docs_dir.join("test")
      FileUtils.mkdir_p configuration.docs_dir
      FileUtils.touch test_file

      subject.clear_docs

      File.directory?(configuration.docs_dir).should be_true
      File.exists?(test_file).should be_false
    end

    it "should rebuild the public docs directory" do
      test_file = configuration.public_docs_dir.join("test")
      FileUtils.mkdir_p configuration.public_docs_dir
      FileUtils.touch test_file

      subject.clear_docs

      File.directory?(configuration.public_docs_dir).should be_true
      File.exists?(test_file).should be_false
    end
  end

  describe "#document_example" do
    let(:example) { stub }
    let(:wrapped_example) { stub(:should_document? => true, :public? => false) }

    before do
      RspecApiDocumentation::Example.stub!(:new).and_return(wrapped_example)
    end

    it "should create a new wrapped example" do
      RspecApiDocumentation::Example.should_receive(:new).with(example).and_return(wrapped_example)
      documentation.document_example(example)
    end

    context "when the given example should be documented" do
      before { wrapped_example.stub!(:should_document?).and_return(true) }

      it "should add the wrapped example to the list of examples" do
        documentation.document_example(example)
        documentation.examples.last.should equal(wrapped_example)
      end

      it "should add the example to the private index" do
        documentation.private_index.should_receive(:add_example).with(example)
        documentation.document_example(example)
      end

      context "when the given example should be publicly documented" do
        before { wrapped_example.stub!(:public? => true) }

        it "should add the given example to the public index" do
          documentation.public_index.should_receive(:add_example).with(example)
          documentation.document_example(example)
        end
      end

      context "when the given example should not be publicly documented" do
        before { wrapped_example.stub!(:public? => false) }

        it "should not add the given example to the public index" do
          documentation.public_index.should_not_receive(:add_example)
          documentation.document_example(example)
        end
      end
    end

    context "when the given example should not be documented" do
      before { wrapped_example.stub!(:should_document?).and_return(false) }

      it "should not add the wrapped example to the list of examples" do
        documentation.document_example(example)
        documentation.examples.should_not include(wrapped_example)
      end

      it "should not add the example to the private index" do
        documentation.private_index.should_not_receive(:add_example)
        documentation.document_example(example)
      end

      it "should not add the example to the public index" do
        documentation.public_index.should_not_receive(:add_example)
        documentation.document_example(example)
      end
    end
  end

  describe "#write_examples" do
    let(:examples) { Array.new(2) { stub } }

    before do
      documentation.stub!(:examples).and_return(examples)
    end

    it "should write each example" do
      examples.each do |example|
        documentation.should_receive(:write_example).with(example)
      end
      documentation.write_examples
    end
  end

  describe "#write_example" do
    include FakeFS::SpecHelpers

    let(:metadata) { stub }
    let(:wrapped_example) { stub(:metadata => metadata) }

    before do
      wrapped_example.stub!(:dirname).and_return('test_dir')
      wrapped_example.stub!(:filename).and_return('test_file')
      wrapped_example.stub!(:template_path=)
      wrapped_example.stub!(:template_extension=)
      wrapped_example.stub!(:render).and_return('rendered content')

      documentation.clear_docs
    end

    it "should set the template path to the configuration value" do
      template_path = stub
      configuration.stub!(:template_path).and_return(template_path)
      wrapped_example.should_receive(:template_path=).with(template_path)
      documentation.write_example(wrapped_example)
    end

    it "should set the template extension to the configuration value" do
      template_extension = stub
      configuration.stub!(:template_extension).and_return(template_extension)
      wrapped_example.should_receive(:template_extension=).with(template_extension)
      documentation.write_example(wrapped_example)
    end

    it "should use Mustache to render the example's metadata with the configured template" do
      wrapped_example.should_receive(:render)
      documentation.write_example(wrapped_example)
    end

    it "should write the rendered content to the correct file" do
      documentation.write_example(wrapped_example)
      File.read(configuration.docs_dir.join('test_dir', 'test_file.html')).should eq('rendered content')
    end
  end
end

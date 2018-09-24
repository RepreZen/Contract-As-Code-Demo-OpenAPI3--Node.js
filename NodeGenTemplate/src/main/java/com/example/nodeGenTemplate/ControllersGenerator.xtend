package com.example.nodeGenTemplate

import com.modelsolv.reprezen.generators.api.GenerationException
import com.modelsolv.reprezen.generators.api.openapi3.OpenApi3DynamicGenerator
import com.modelsolv.reprezen.generators.api.template.IGenTemplateContext
import com.reprezen.kaizen.oasparser.model3.OpenApi3
import com.reprezen.kaizen.oasparser.model3.Operation
import com.reprezen.kaizen.oasparser.model3.Parameter
import com.reprezen.kaizen.oasparser.model3.RequestBody
import java.util.HashSet
import java.util.List

class ControllersGenerator extends OpenApi3DynamicGenerator {
	extension ModelHelper = new ModelHelper
	extension ModuleNameHelper = new ModuleNameHelper

	var OpenApi3 model
	val generatedOps = new HashSet<Operation>()

	override generate(OpenApi3 model) throws GenerationException {
		this.model = model;
		for (tag : model.allTags) {
			generate(tag, model)
		}
		generate(null, model)
	}

	def private generate(String tag, OpenApi3 model) {
		val allOps = model.paths.values.map[path|path.operations.values].flatten.toList
		// filter for matching tag if provided tag is not null
		val tagOps = allOps.filter[tag === null || it.tags.contains(tag)].toList
		// skip already-generated operations
		val ops = tagOps.filter[!generatedOps.contains(it)]
		if (!ops.empty) {
			new ControllersFile(context, tag.moduleName, ops.toList).generate()
			generatedOps.addAll(ops)
		}
	}
}

class ControllersFile extends GeneratedFile {
	extension ModelHelper = new ModelHelper
	extension MethodNameHelper = new MethodNameHelper
	extension ParamsHelper = new ParamsHelper
	
	val List<Operation> operations
	val String name

	new(IGenTemplateContext context, String name, List<Operation> operations) {
		super(context, true)
		this.name = name
		this.operations = operations
	}

	override getContent() {
		'''
			// jshint esversion:6, latedef:nofunc
			
			const router = require('express').Router();
			const «name»Handler = require('../handlers/«name»');
			
			«FOR op : operations SEPARATOR "\n"»
				«op.getContent(name)»
			«ENDFOR»
			
			function handle(res, response) {
				res.status(response ? 200 : 201);
				if (response) {
					res.json(response);
				}
			}
			
			module.exports = router;
		'''
	}

	def private getContent(Operation op, String moduleName) {
		'''
			router.«op.method»('«op.path.expressPathString»', (req, res) => {
				new «moduleName»Handler(req.app.locals.db).«op.methodName»(«op.argList.join(", ")»)
				.then((response) => handle(res, response))
				.catch((error) => res.status(error.code).send(error.message));
			});
		'''
	}

	def private getArgList(Operation op) {
		op.allParameters.map[
			switch it {
				Parameter: it.expressExpr
				RequestBody: "req.body"				
			}
		]
	}

	override getRelativeFile() {
		return '''controllers/«name».js'''
	}

}

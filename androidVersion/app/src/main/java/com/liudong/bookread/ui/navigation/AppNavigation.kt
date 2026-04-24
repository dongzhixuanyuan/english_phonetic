package com.liudong.bookread.ui.navigation

import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.liudong.bookread.ui.detail.TextbookDetailScreen
import com.liudong.bookread.ui.home.HomeScreen
import com.liudong.bookread.ui.reader.ReaderScreen
import com.liudong.bookread.viewmodel.TextbookViewModel

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val viewModel: TextbookViewModel = viewModel()

    NavHost(navController = navController, startDestination = "home") {
        composable("home") {
            HomeScreen(viewModel = viewModel, navController = navController)
        }
        composable(
            "detail/{textbookId}",
            arguments = listOf(navArgument("textbookId") { type = NavType.StringType })
        ) { backStackEntry ->
            val textbookId = backStackEntry.arguments?.getString("textbookId")!!
            TextbookDetailScreen(viewModel, textbookId, navController)
        }
        composable(
            "reader/{textbookId}/{unitId}/{pageId}",
            arguments = listOf(
                navArgument("textbookId") { type = NavType.StringType },
                navArgument("unitId") { type = NavType.StringType },
                navArgument("pageId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val textbookId = backStackEntry.arguments?.getString("textbookId")!!
            val unitId = backStackEntry.arguments?.getString("unitId")!!
            val pageId = backStackEntry.arguments?.getString("pageId")!!
            ReaderScreen(viewModel, textbookId, unitId, pageId, navController)
        }
    }
}
